#! /bin/sh

print_help()
{
cat << EOH
Prepares the source tree for configuration

Usage:
  autogen.sh [sydeps [--install-yum|--install-dnf]]

Options:

  sysdeps              prints out all dependencies
    --install-yum      install all dependencies ('sudo yum install \$DEPS')
    --install-dnf      install all dependencies ('sudo dnf install \$DEPS')

EOH
}

build_depslist()
{
    DEPS_LIST=`grep "^\(Build\)\?Requires:" *.spec.in | grep -v "%{name}" | tr -s " " | tr "," "\n" | cut -f2 -d " " | grep -v "^abrt" | sort -u | while read br; do if [ "%" = ${br:0:1} ]; then grep "%define $(echo $br | sed -e 's/%{\(.*\)}/\1/')" *.spec.in | tr -s " " | cut -f3 -d" "; else echo $br ;fi ; done | tr "\n" " "`
}

case "$1" in
    "--help"|"-h")
            print_help
            exit 0
        ;;
    "sysdeps")
            build_depslist

            if [ "$2" == "--install" ] || [ "$2" == "--install-dnf" ]; then
                set -x verbose
                sudo dnf install --setopt=strict=0 $DEPS_LIST
                set +x verbose
            elif [ "$2" == "--install-yum" ]; then
                set -x verbose
                sudo yum install $DEPS_LIST
                set +x verbose
            else
                echo $DEPS_LIST
            fi
            exit 0
        ;;
    *)
            echo "Generating new version ..."
            ./gen-version

            mkdir -p m4
            echo "Creating m4/aclocal.m4 ..."
            test -r m4/aclocal.m4 || touch m4/aclocal.m4

            echo "Running autopoint"
            autopoint --force || exit 1

            echo "Running intltoolize..."
            intltoolize --force --copy --automake || exit 1

            echo "Running aclocal..."
            aclocal || exit 1

            echo "Running libtoolize..."
            libtoolize || exit 1

            echo "Running autoheader..."
            autoheader || exit 1

            echo "Running autoconf..."
            autoconf --force || exit 1

            echo "Running automake..."
            automake --add-missing --force --copy || exit 1

            echo "Running configure ..."
            if [ 0 -eq $# ]; then
                ./configure \
                    --prefix=/usr \
                    --mandir=/usr/share/man \
                    --infodir=/usr/share/info \
                    --sysconfdir=/etc \
                    --localstatedir=/var \
                    --sharedstatedir=/var/lib \
                    --enable-debug
                echo "Configured for local debugging ..."
            else
                ./configure "$@"
            fi
        ;;
esac

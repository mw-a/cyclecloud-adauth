#!/bin/sh

cat <<'EOF' > /etc/profile.d/shared.sh
pathmunge () {
    case ":${PATH}:" in
        *:"$1":*)
            ;;
        *)
            if [ "$2" = "after" ] ; then
                PATH=$PATH:$1
            else
                PATH=$1:$PATH
            fi
    esac
}

pathmunge /shared/appl/bin after

unset -f pathmunge
EOF

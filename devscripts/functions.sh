warn () {
    if [ -n "$1" ]; then
        echo "$@" >&2
    else
        cat >&2
    fi
}

die () {
    warn "$@"
    exit 1
}

dockermysql () {
    local dockerbash="docker compose exec -T db bash -c"
    case "$1" in
        mysql|mysqldump)
            local cmd="$1"; shift
            case "$#" in
                0) $dockerbash "$cmd -p\$MARIADB_ROOT_PASSWORD" ;;
                *) $dockerbash "$cmd -p\$MARIADB_ROOT_PASSWORD $*" ;;
            esac ;;
        *)
            $dockerbash "$*" ;;
    esac
}

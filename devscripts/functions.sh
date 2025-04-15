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

dockermariadb () {
    local dockerbash="docker compose exec -T mariadb bash -c"
    case "$1" in
        mariadb|mysqldump)
            local cmd="$1"; shift
            case "$#" in
                0) $dockerbash "$cmd -p\$MARIADB_ROOT_PASSWORD" ;;
                *) $dockerbash "$cmd -p\$MARIADB_ROOT_PASSWORD $*" ;;
            esac ;;
        *)
            $dockerbash "$*" ;;
    esac
}

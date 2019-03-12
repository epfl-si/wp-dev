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
    docker exec -i wp-local_db_1 bash -c 'mysql -p$MYSQL_ROOT_PASSWORD'
}

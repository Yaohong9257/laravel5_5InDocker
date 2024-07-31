#!/bin/bash

# 错误处理函数
handle_error() {
    echo "错误: $1"
    exit 1
}

# 更新代码到预发布环境
setup_pre_project() {
    local project="$1"
    local pre_project="${project}_pre"

    # 拷贝原项目到临时目录
    cp -a "../${project}" "../${pre_project}" || handle_error "拷贝项目失败"

    cd "../${pre_project}" || handle_error "目录切换失败"

    # 获取最新代码
    git fetch --all || handle_error "获取最新代码失败"
    git checkout master || handle_error "切换到master分支失败"
    git pull origin master || handle_error "拉取最新代码失败"

    # 安装 Composer 依赖
    echo "正在安装 Composer 依赖..."
    if ! docker exec php7 bash -c "cd /var/www/${pre_project} && composer install"; then
        handle_error "Composer 安装失败, 请检查"
    fi

    # 执行数据库迁移和数据填充
    docker exec php7 php /var/www/"${pre_project}"/artisan migrate --force || handle_error "数据库迁移失败"
    docker exec php7 php /var/www/"${pre_project}"/artisan db:seed --class=BackendSeeder --force || handle_error "数据库填充失败"

    # 重启系统的 Nginx 服务
    sudo systemctl restart nginx

    # 重启 Docker 容器
    docker restart new_nginx
    docker restart nginx
}

# 发布生产环境项目
setup_pro_project() {
    local project="$1"
    local date_suffix=$(date +%Y_%m_%d)
    local bak_project="${project}_${date_suffix}_bak"

    mv "../${project}" "../${bak_project}" || handle_error "重命名生产项目失败"
    mv "../${project}_pre" "../${project}" || handle_error "重命名预发布项目失败"

    reload_supervisor
}

# 重新加载 Supervisor 配置
reload_supervisor() {
    echo "正在重新加载 Supervisor 配置..."

    systemctl restart supervisord || handle_error "重启supervisord 失败"

    # 重新读取 Supervisor 配置
    if sudo supervisorctl reread; then
        echo "Supervisor 配置读取成功"
    else
        handle_error "Supervisor 配置读取失败"
    fi

    # 更新 Supervisor 配置
    if sudo supervisorctl update; then
        echo "Supervisor 配置更新成功"
    else
        handle_error "Supervisor 配置更新失败"
    fi

    supervisorctl status
    echo "Supervisor 配置已重新加载"
}

main() {
    local func="$1"
    local arg="$2"

    if [[ $# -eq 2 && $(type -t "$func") == "function" ]]; then
        "$func" "$arg"
        return
    fi

    # 如果参数不符合以上两种情况, 则输出使用方法
    echo "Usage:"
    echo "  main [function_name] [arg]  # 执行指定函数"
    exit 1

}

# 调用主函数并传入参数
main "$@"
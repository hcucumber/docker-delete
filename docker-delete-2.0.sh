#!/bin/bash

# 设置仓库目录变量，存储 Docker Registry 的仓库信息
repositories_dir=$DOCKER_REGISTRY_DIR/docker/registry/v2/repositories
# 设置 Blobs 目录变量，存储 Docker Registry 的 Blobs 信息
blobs_dir=$DOCKER_REGISTRY_DIR/docker/registry/v2/blobs/sha256/

# 检查配置函数
function checkConfiguration(){
    # 初始化通过标志为 true
    pass="true"

    # 如果环境变量 DOCKER_REGISTRY_CONTAINER_ID 未设置
    if [! "$DOCKER_REGISTRY_CONTAINER_ID" ]; then
        # 输出错误信息，提示设置该环境变量
        echo -e "\033[31;1m Please set the env variable 'DOCKER_REGISTRY_CONTAINER_ID'.\033[0m"
        # 将通过标志设为 false
        pass="false"
    else
        # 统计容器 ID 与环境变量 DOCKER_REGISTRY_CONTAINER_ID 匹配的正在运行的容器数量
        containerNum=`docker ps | awk '{print $1}' | grep "$DOCKER_REGISTRY_CONTAINER_ID" |awk 'END{print NR}'`
        # 如果没有匹配的正在运行的容器
        if [ $containerNum == '0' ]; then
            # 输出错误信息，提示没有找到对应的容器，并提示检查环境变量是否正确
            echo -e "\033[31;1m No such running container : '$DOCKER_REGISTRY_CONTAINER_ID'.\033[0m"
            echo -e "\033[31;1m Please check that the env variable 'DOCKER_REGISTRY_CONTAINER_ID' is correct.\033[0m"
            # 将通过标志设为 false
            pass="false"
        else
            # 统计容器 ID 与环境变量 DOCKER_REGISTRY_CONTAINER_ID 匹配且容器名称为 registry 的正在运行的容器数量
            registryContainerNum=`docker ps | awk '{print $1,$2}' | grep "$DOCKER_REGISTRY_CONTAINER_ID" | grep "registry" |awk 'END{print NR}'`
            # 如果没有找到对应的 Docker Registry 容器
            if [ $registryContainerNum == '0' ]; then
                # 输出错误信息，提示找到的容器不是 Docker Registry 容器，并提示检查环境变量是否正确
                echo -e "\033[31;1m The container : '$DOCKER_REGISTRY_CONTAINER_ID' is running,but it is not a Docker Registry containser.\033[0m"
                echo -e "\033[31;1m Please check that the env variable 'DOCKER_REGISTRY_CONTAINER_ID' is correct.\033[0m"
                # 将通过标志设为 false
                pass="false"
            fi
        fi
    fi

    # 如果环境变量 DOCKER_REGISTRY_DIR 未设置
    if [! "$DOCKER_REGISTRY_DIR" ]; then 
        # 输出错误信息，提示设置该环境变量
        echo -e "\033[31;1m Please set the env variable 'DOCKER_REGISTRY_DIR'.\033[0m"
        # 将通过标志设为 false
        pass="false"
    else
        # 判断仓库目录是否存在
        if [! -d "$repositories_dir" ]; then 
            # 输出错误信息，提示设置的 DOCKER_REGISTRY_DIR 不是有效的 Docker Registry 目录，并提示检查环境变量是否正确
            echo -e "\033[31;1m '$DOCKER_REGISTRY_DIR' is not a Docker Registry dir.\033[0m"
            echo -e "\033[31;1m Please check that the env variable 'DOCKER_REGISTRY_DIR' is correct.\033[0m"
            # 将通过标志设为 false
            pass="false"
        fi
    fi

    # 如果通过标志为 false
    if [ $pass == "false" ]; then
        # 以状态码 2 退出脚本
        exit 2
    fi
}

# 删除 Blobs 函数
function deleteBlobs(){
    # 在指定的 Docker Registry 容器中执行垃圾回收命令
    docker exec -it $DOCKER_REGISTRY_CONTAINER_ID  sh -c ' registry garbage-collect /etc/docker/registry/config.yml'

    # 查找 Blobs 目录下的空目录
    emptyPackage=`find $blobs_dir -type d -empty`

    # 如果有找到空目录
    if [ "$emptyPackage" ]; then
        # 删除找到的空目录
        find $blobs_dir -type d -empty | xargs -n 1 rm -rf

        # 重启 Docker Registry 容器
        restartRegistry=`docker restart $DOCKER_REGISTRY_CONTAINER_ID`
        # 如果重启成功
        if [ $restartRegistry == "$DOCKER_REGISTRY_CONTAINER_ID"  ]; then
            # 输出成功信息
            echo -e "\033[32;1m Successful restart of registry container\033[0m"
        fi
        # 输出成功删除 Blobs 的信息
        echo -e "\033[32;1m Successful deletion of blobs\033[0m"
    fi
}

# 显示帮助信息函数
function showHelp(){
    # 输出用法信息
    echo -e "\033[31;1m Usage: \033[0m"
    echo -e "\033[31;1m docker-delete -sr                                   [description: show all image repositories] \033[0m"
    echo -e "\033[31;1m docker-delete -st <image repository>                [description: show all tags of specified image repository] \033[0m"
    echo -e "\033[31;1m docker-delete -dr <image repository>                [description: delete specified image repository ] \033[0m"
    echo -e "\033[31;1m docker-delete -dr -all                              [description: delete all image repositories ]"
    echo -e "\033[31;1m docker-delete -dt <image repository> <image tag>    [description: description: delete specified tag of specified image repository ] \033[0m"
    echo -e "\033[31;1m docker-delete -dt <image repository>                [description: description: delete all tags of specified image repository ] \033[0m"
}

# 检查仓库是否存在函数
function checkRepositoryExist(){
    # 设置仓库目录
    repository_dir=$repositories_dir/$1
    # 如果仓库目录不存在
    if [! -d "$repository_dir" ];then
        # 输出错误信息，提示没有找到对应的仓库，并给出查看所有仓库的方法
        echo -e "\033[31;1m no such image repository : $1.\033[0m"
        echo -e "\033[31;1m you can use 'docker-delete -sr' to show all repositories.\033[0m"
        # 以状态码 2 退出脚本
        exit 2
    fi
}

# 检查标签是否存在函数
function checkTagExist(){
    # 设置标签目录
    tag_dir=$repositories_dir/$1/_manifests/tags/$2
    # 如果标签目录不存在
    if [! -d "$tag_dir" ];then
        # 输出错误信息，提示没有找到对应的标签，并给出查看指定仓库下所有标签的方法
        echo -e "\033[31;1m no such image tag : '$2' under $1.\033[0m"
        echo -e "\033[31;1m you can  use 'docker-delete -st $1' to  show all tags of $1.\033[0m"
        # 以状态码 2 退出脚本
        exit 2
    fi
}

# 首先检查配置
checkConfiguration

# 如果没有提供参数
if [! -n "$1" ];then 
    # 显示帮助信息
    showHelp
else
    # 如果第一个参数是 -sr
    if [ $1 == '-sr' ]; then
        # 切换到仓库目录
        cd $repositories_dir
        # 查找所有仓库的 _manifests 目录，并截取仓库名称
        repositories=`find. -name "_manifests" | cut -b 3-`
        # 如果没有找到仓库
        if [! "$repositories" ];then 
            # 输出没有仓库的错误信息
            echo -e "\033[31;1m No image repository existence.\033[0m"
        fi
        # 输出找到的仓库名称，以蓝色字体显示
        echo -e "\033[34;1m${repositories//\/_manifests/}\033[0m"
        # 以状态码 0 退出脚本，表示成功执行
        exit 0
    fi

    # 如果第一个参数是 -st
    if [ $1 == '-st' ]; then
        # 如果没有提供仓库名称参数
        if [! $2 ]; then
            # 输出错误信息，提示正确的用法
            echo -e "\033[31;1m use ‘docker-delete -st <image repository>' to show all tags of specified repository.\033[0m"
            # 以状态码 2 退出脚本
            exit 2
        fi
        # 检查仓库是否存在
        checkRepositoryExist "$2"
        # 列出指定仓库下的所有标签
        tags=`ls $repositories_dir/$2/_manifests/tags`
        # 如果没有找到标签
        if [! "$tags" ]; then 
            # 输出没有标签的错误信息
            echo -e "\033[31;1m No tag under $2.\033[0m"
        fi
        # 输出找到的标签名称，以蓝色字体显示
        echo -e "\033[34;1m$tags\033[0m"
        # 以状态码 0 退出脚本，表示成功执行
        exit 0
    fi

    # 如果第一个参数是 -dr
    if [ $1 == '-dr' ]; then
        # 如果没有提供仓库名称参数或不是 -all 参数
        if [! $2 ]; then
            # 输出错误信息，提示正确的用法
            echo -e "\033[31;1m use ‘docker-delete -dr <image repository>' to delete specified repository\033[0m"
            echo -e "\033[31;1m or ‘docker-delete -dr -all’ to delele all repositories.\033[0m"
            # 以状态码 2 退出脚本
            exit 2
        fi
        # 如果是 -all 参数
        if [ $2 == '-all' ]; then
            # 删除所有仓库目录
            rm -rf $repositories_dir/*
            # 删除 Blobs
            deleteBlobs
            # 输出成功删除所有仓库的信息
            echo -e "\033[32;1m Successful deletion of all image repositories.\033[0m"
            # 以状态码 0 退出脚本，表示成功执行
            exit 0
        fi
        # 检查仓库是否存在
        checkRepositoryExist "$2"

        # 删除指定仓库目录
        rm -rf $repositories_dir/$2

        # 设置空仓库目录数量初始值为 1
        emptyRepositoriesNum=1

        # 循环删除空的仓库目录，直到没有空目录为止
        while [ $emptyRepositoriesNum!= "0" ]
        do
            find $repositories_dir -type d -empty | grep -v "_manifests" | grep -v "_layers" | grep -v "_uploads" | xargs -n 1 rm -rf
            emptyRepositoriesNum=`find $repositories_dir -type d -empty | grep -v "_manifests" | grep -v "_layers" | grep -v "_uploads" | awk 'END{print NR}'`
        done

        # 删除 Blobs
        deleteBlobs
        # 输出成功删除指定仓库的信息
        echo -e "\033[32;1m Successful deletion of image repository:\033[0m \033[34;1m$2.\033[0m"
        # 以状态码 0 退出脚本，表示成功执行
        exit 0
    fi

    # 如果第一个参数是 -dt
    if [ $1 == '-dt' ]; then

        # 如果没有提供仓库名称参数
        if [! $2 ]; then
            # 输出错误信息，提示正确的用法
            echo  -e "\033[31;1m use ‘docker-delete -dt <image repository> <images tag>' to delete specified tag of specified repository  \033[0m"
            echo  -e "\033[31;1m or ‘docker-delete -dt <image repository>’ to delele all tags of specified repository.\033[0m"
            # 以状态码 2 退出脚本
            exit 2
        fi

        # 检查仓库是否存在
        checkRepositoryExist "$2"

        # 设置标签目录和修订目录变量
        tags_dir=$repositories_dir/$2/_manifests/tags
        sha256_dir=$repositories_dir/$2/_manifests/revisions/sha256
        # 如果没有提供标签名称参数
        if [! $3 ]; then
            # 提示用户是否要删除指定仓库的所有标签，并读取用户输入
            read -p "do you want to delete all tags of '$2'?,please input yes or no : " yes
            # 如果用户输入 yes
            if [ $yes == "yes" ];then
                # 删除指定仓库的所有标签目录和修订目录
                rm -rf $tags_dir/*
                rm -rf $sha256_dir/*
                # 删除 Blobs
                deleteBlobs
                # 输出成功删除指定仓库所有标签的信息
                echo -e "\033[32;1m Successful deletion of all tags under \033[0m \033[34;1m$2\033[0m"
                # 以状态码 0 退出脚本，表示成功执行
                exit 0
            else
                # 以状态码 2 退出脚本
                exit 2
            fi
        fi

        # 检查标签是否存在
        checkTagExist "$2" "$3"

        # 获取指定标签的摘要信息
        digest=`ls $tags_dir/$3/index/sha256`
        # 统计包含该摘要信息的目录数量
        digestNum=`find $repositories_dir/*/_manifests/tags -type d -name "$digest" | awk 'END{print NR}'`

        # 如果只有一个包含该摘要信息的目录
        if [ "$digestNum" == '1' ]; then
            # 删除对应的修订目录
            rm -rf $sha256_dir/$digest
        fi

        # 删除指定标签目录
        rm -rf $tags_dir/$3

        # 获取指定仓库下的所有标签
        tags=`ls $tags_dir`

        # 如果没有标签了
        if [! "$tags" ]; then
            # 删除所有修订目录
            rm -rf $sha256_dir/*
        fi

        # 删除 Blobs
        deleteBlobs
        # 输出成功删除指定标签的信息
        echo  -e "\033[32;1m Successful deletion of\033[0m \033[34;1m$2:$3\033[0m"
        # 以状态码 0 退出脚本，表示成功执行
        exit 0

    fi
    # 如果参数不匹配任何已知的选项，显示帮助信息
    showHelp
fi

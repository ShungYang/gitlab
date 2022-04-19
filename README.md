# DevSecOps use GitLab

* 使用 docker-compose 執行 GitLab, 並且運行 GitLab Runner 作為 Continuous integration / Continuous Deployment (CI/CD) 工具
* 目的是為了實現 [DevSecOps](https://www.ibm.com/tw-zh/cloud/learn/devsecops) , 我在 [pipeline](http://10.88.26.237/docker/gitlab/-/blob/main/.gitlab-ci.yml) 定義了幾 4 個 stages 如下
  * ___build___ : 使用 [Docker Executor](http://10.88.26.237/docker/gitlab/-/blob/main/README-docker-executor.md) 去 build docker image
  * ___scan___ : 使用 Docker Executor 整合使用 SonarQube 做程式碼的安全性分析, 詳細可參考[說明文件](https://docs.sonarqube.org/latest/analysis/gitlab-integration/)和[.gitlab-ci.yml](http://10.88.26.237/docker/gitlab/-/blob/main/.gitlab-ci.yml)
  * ___publish___ : 使用 Docker Executor 把之前在 build stage 打包好的 docker image publish 到 [Nexus docker registry](http://10.88.26.237/docker/nexus-server/-/tree/main) 上.
  * ___deploy___ : 在欲運行 docker container service 的 host 上 `install` gitlab runner 註冊為 [Shell Executor]((http://10.88.26.237/docker/gitlab/-/blob/main/README-shell-executor.md)) 來運行容器服務.

## GitLab Runner

> GitLab Runner is an application that works with GitLab CI/CD to run jobs in a pipeline.

GitLab Runner 有許多種安裝方式, 只要 OS 能編譯 Go GitLab Runner 那就能運作, 我選擇的方式是將 GitLab Runner 作為 Docker container 的方式運行, 好處如下:

* 運行方便且容易.
* 擴展容易, 如果有許多 jobs 要執行, Runner 會需要水平擴充來執行排隊中的 jobs.

另外也可以部屬在 Kubernetes 群集中.

## The scope of runners

能使用的 Runners 可以分為以下三種:

* `Shared runners` : 所有的 groups 和 projects.
* `Group runners` : 在 group 中的所有 projects 和 subgroups.
* `Specific runners` : 專屬於某個指定的 projects.

## Install the Docker image and start the container

先確定 host system 已經安裝了 docker, 由於我將 gitlab-runner 運行在 Docker container 中, 為了不要在 container 重啟時導致 gitlab-runner 的設定消失, 我們需要替 gitlab-runner 掛載 `docker volume`.

首先建立 volume gitlab-runner-config

```
docker volume create gitlab-runner-config
```

接著將運行 gitlab-runner 運行在容器中

```
docker run -d --name gitlab-runner-docker --restart always \
    --env TZ=Asia/Taipei \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v gitlab-runner-config:/etc/gitlab-runner \
    gitlab/gitlab-runner:ubuntu-v14.9.1
```

* 注意將環境變數配置所在的時區, [View a list of available time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
* 需要掛載 /var/run/docker.sock 才能讓 gitlab-runner 使用 host system 的 docker daemon
* [使用 gitlab-runner image 的資訊](https://hub.docker.com/r/gitlab/gitlab-runner/tags)

當 gitlab-runner-docker 運行後, 可以進去看看其實容器的環境中是沒有安裝 docker 的

```
docker exec -it gitlab-runner-docker /bin/bash
```

## Get the logs

```
docker logs gitlab-runner-docker
```

## Register the runner

接下來的步驟是讓 gitlab-runner 向 GitLab server 進行註冊的動作, 這樣當 GitLab server 有 pipline 要運行時, 才能分配其中的 job 給 gitLab-runner.

透過 ___docker exec -it___ 運行註冊指令 ___gitlab-runner register___

```
docker exec -it gitlab-runner-docker gitlab-runner register
```

而在註冊的過程中 gitlab-runner 會定義 executor, 一個 executor 代表 job 被執行的環境, 而 runner 實作了許多不同的 [Executors](https://docs.gitlab.com/runner/executors/#selecting-the-executor) 來滿足不同的 job 使用情境, 整個 Pipeline 我會使用兩種 Executor 分別是 Docker Executor 和 Shell Executor, 進一步的說明和設定可以參考連結.

note. `一個 Runner 可以被 register 多次, 或多種 Executor`.

在註冊成功後就可以在 GitLab server 上看到該 Runner 為 Online 的狀態.
另外這些設定會寫入到先前綁定的 volume 下的 : `/data/docker/volumes/gitlab-runner-config/_data/config.toml`

我們還需要針對 Docker Executor 在 [config.toml](http://10.88.26.237/docker/gitlab/-/blob/main/config.toml) 中加入一個環境變數:

* `DOCKER_AUTH_CONFIG` : 讓我們可以在 Docker Executor 中能存取 Nexus docker registry 中的 image.

## Update configuration

每一次更改了 config.toml 後需要重啟 Runner 套用變更.

```
docker restart gitlab-runner-docker
```

## Upgrade gitlab-runner version

也相當的方便, 只要停止正在運行的 gitlab-runner-docker, 並以新版的 gitlab-runner image 重新啟動即可.

```
docker stop gitlab-runner && docker rm gitlab-runner
```

## Reference Link

* [A Brief Guide to GitLab CI Runners and Executors](https://medium.com/devops-with-valentine/a-brief-guide-to-gitlab-ci-runners-and-executors-a81b9b8bf24e) by Valentin Despa
* [GitLab CI/CD: Print All Environment Variables](https://www.shellhacks.com/gitlab-ci-cd-print-all-environment-variables/) by ShellHacks
* [Day06 - GitLab CI 變數還可以怎麼定義？再談 GitLab 各層級變數](https://ithelp.ithome.com.tw/articles/10241429) by 墨嗓

__Enjoy!__

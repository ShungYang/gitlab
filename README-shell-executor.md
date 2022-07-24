# The Shell Executor

> The Shell executor is a simple executor that you use to execute builds locally on the machine where GitLab Runner is installed. It supports all systems on which the Runner can be installed.

我需要在 Deploy 階段使用 docker pull 從 Nexus docker registry 下載先前 docker push 的 image, 並且 docker run 把服務運行起來, 所以有以下幾個要點:

* 需要在欲運行服務的 host 上 `install` gitlab runner [參考](https://docs.gitlab.com/runner/install/linux-manually.html), 而不是像之前使用 gitlab runner container, 因為我們 docker run 時容器需要運行在 host 上.
* gitlab runner 需要註冊為 Shell Executor, 在 script 中去運行 docker command.
* host 環境必定要安裝 docker. (可視情況另外安裝 docker-compose)

## Register the runner as shell executor

運行註冊指令 ___gitlab-runner register___

```
sudo gitlab-runner register
```

因為我要直接在 Host 上去 run docker image, 所以這個 runner 註冊時要設定為 Shell Executor, 註冊的過程有幾個 Q&A

* Enter your GitLab instance URL.
* Enter the token you obtained to register the runner.
  * 以 shared-runner 為例 : Admin Area > Runners > Register an instance runner
  * 以 project-runner 為例 : Project Settings > CI/ CD > Runners
* Enter a description for the runner.
* Enter the tags associated with the runner.
  * 這邊使用 `shell`.
  * 之後我會在 [.gitlab-ci.yml](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci.yml) 中的 job 透過 `tag` 指定要執行在哪個 runner.
  * 而一個 Runner 可有多個 tag 並使用逗號分隔
  * 另外可以在 GitLab server 針對 Runner 設定是否 `Run untagged jobs`
* Enter any optional maintenance note for the runner.
* Provide the runner executor. For most use cases, enter ___shell___

## Overview

Shell executor 在執行 job 時

* 會將專案 checked out 到這個目錄並且 .git 也會存在這裡 : <working-directory>/builds/<short-token>/<concurrent-id>/<namespace>/<project-name>. (ex. /home/gitlab-runner/builds/)

* 執行過程中的 caches 會被保存在 : <working-directory>/cache/<namespace>/<project-name>.

## Important

* 新增 gitlab-runner user 到 docker group.

```
sudo usermod -aG docker gitlab-runner
```

* 驗證能否存取 docker

```
sudo -u gitlab-runner -H docker info
```

* 如果需要修改 gitlab-runner 設定文件, 位置如下 (gitlab-runner 每10秒會自動 reload config.toml)

```
sudo vim /etc/gitlab-runner/config.toml
```

## Use Helm CLI

* 如果要使用 Helm manager 來發佈服務到 K8S 群集中的話, 需要額外安裝 Helm3, 可參考這篇 [Helm guide](https://github.com/ShungYang/helm-guide)

* 因為在 shell executor 中是以 gitlab-runner 這個 user 來運行 script, 所以需要給 gitlab-runner 有 root 權限才能夠存取其他 user 的擋案, ex. /home/{user}/.kube/config

```bash
sudo usermod -a -G sudo gitlab-runner
```

```bash
sudo vim /etc/sudoers
```

讓 gitlab-runner 不用輸入 sudo 密碼
`gitlab-runner ALL=(ALL) NOPASSWD: ALL`

## Reference Link

* [The Shell executor](https://docs.gitlab.com/runner/executors/shell.html) by GitLab Document
* [Use Shell executor to build Docker images](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-socket-binding) by GitLab Document

__Enjoy!__

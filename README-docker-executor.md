# The Docker executor

* 每一次的 build 都是在一個乾淨的環境中 (因為在容器中運行) 且容易擴展重現的.
* 所以是和 host 系統相互隔離不受影響的, 不會在 build 的過程去修改到 host的環境變數.

Docker executor 會使用 Docker Engine 在獨立不受干擾的容器環境中執行 CI/CD jobs, Docker executor 使用的 image keyword 可以依照使用情境定義在 `gitlab-ci.yml (by project)` 或是 `config.toml (by runner)`.

## Docker-in-Docker

我的使用情境是要在 Docker container (來自於 image keyword 指定的環境) 中去操作 docker daemon, ex. docker build, docker pull, docker push.
這種使用情境稱為 ___Docker-in-Docker (dind)___, 關於 Docker executor 要使用 Docker-in-Docker 執行 job, 官方文件中有提供以下兩種方式:

* [Service kyeword use dind image](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker)
* [Use Docker socket binding](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-socket-binding)

這邊有篇文章針對 Docker-in-Docker 做了[分析比較](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/), 一般都是建議使用 `Use Docker socket binding` 的方式來避掉底層的問題和降低複雜化. 官網的步驟說明得很詳細, 我這邊仍透過使用 docker-dind 的 image 做為 docker daemon 來達到 Docker-in-Docker 的使用情境.

## Workflow

Docker executor 執行 job 時會分為以下幾個階段:

* ___Prepare___ : Create and start the services.
* ___Pre-job___ : Clone, restore cache and download artifacts from previous stages. This is run on a special Docker image.
* ___Job___ : User build. This is run on the user-provided Docker image.
* ___Post-job___ : Create cache, upload artifacts to GitLab. This is run on a special Docker Image.

## Register the runner as docker executor

因為我要在 Docker container 中去 build docker image, 所以這個 runner 註冊時要設定為 Docker Executor, 註冊的過程有幾個 Q&A

* Enter your GitLab instance URL.
* Enter the token you obtained to register the runner.
  * 以 shared-runner 為例 : Admin Area > Runners > Register an instance runner
  * 以 project-runner 為例 : Project Settings > CI/ CD > Runners
* Enter a description for the runner.
* Enter the tags associated with the runner.
  * 這邊使用 `docker`.
  * 之後我會在 [.gitlab-ci.yml](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci.yml) 中的 job 透過 `tag` 指定要執行在哪個 runner.
  * 而一個 Runner 可有多個 tag 並使用逗號分隔
  * 另外可以在 GitLab server 針對 Runner 設定是否為 [Run untagged jobs](https://docs.gitlab.com/ee/ci/runners/configure_runners.html#use-tags-to-control-which-jobs-a-runner-can-run)
* Enter any optional maintenance note for the runner.
* Provide the runner executor. For most use cases, enter ___docker___ [說明為何使用 Docker Executor](https://github.com/ShungYang/gitlab/blob/master/README-docker-executor.md).
* the default image to be used for projects that do not define one in .gitlab-ci.yml
  * __作為 build docker image 的環境, 目前使用 docker:20.10.13__ (tag 應該要指定明確的版本, 不要使用 latest)

## Important keyword

* ___image keyword___ 指定一個 Docker image 來建立容器, 可以出自 Docker Hub 或是 private registry (加上 namespace), 如果 image ___未加上 tag 那一律視為 latest___ , 接下來我會使用 Nexus server 的 docker registry.

* ___services keyword___ 定義了在 run job 的過程中另外需要連結上 image keyword 所定義的 docker image, 這允許我們在 build 期間去存取使用 service image. service image 可以是任何的應用服務, 大多數是資料庫容器, e.g., mysql. 而在 Docker-in-Docker 的情況至少會使用到 ___docker-dind___ image. 可參考 [CI services examples](https://docs.gitlab.com/ee/ci/services/).

## Define image and services

image 和 service 可依照使用的情境定義在以下的文件中

* [.gitlab-ci.yml](https://docs.gitlab.com/runner/executors/docker.html#define-image-and-services-from-gitlab-ciyml) (by project)
* config.toml (by runner) : 由於目前使用的 CI Pipeline 都有共用的 image 和 service 所以我統一定義在 [config.toml](https://github.com/ShungYang/gitlab/blob/master/config.toml) 中

## Define an image from a private Docker registry

GitLab Runner 0.6.0 之後, 所使用的 image 可以來自於 private docker registry, 那麼一來會有需要進行身分驗證的問題. 例如我們需要存取來自 registry.example.com:5000/private/image:latest 的 image, 那麼我們需要先能 login 來驗證我們的身分.

```
docker login registry.example.com:5000 --username my_username --password my_password
```

接著複製 `~/.docker/config.json` 裡的 auths 屬性, 做為接下來 `DOCKER_AUTH_CONFIG` 的數值.

```json
{
    "auths": {
        "registry.example.com:5000": {
            "auth": "(Base64 'my_username:my_password')"
        }
    }
}
```

根據使用的情境可以透過以下兩種設定的範圍:

* ___Per-job___ : 將 `DOCKER_AUTH_CONFIG` 做為 [CI/CD variable](https://docs.gitlab.com/ee/ci/variables/index.html) 新增在 .gitlab-ci.yml, 並使用以下的方式使用

```
image: my.registry.tld:5000/namepace/image:tag
```

* ___Per-runner___: 新增 `DOCKER_AUTH_CONFIG` 環境變數在 [config.toml](https://github.com/ShungYang/gitlab/blob/master/config.toml), 如果有修改的話必定要重啟 runner 服務.

## Caching in GitLab CI/CD

在 Pipeline 的過程中, 在 job 中所下載或是產生的檔案會讓隨後的 job 也使用到, 這麼一來將檔案做 cache 機制重複使用就很重要. 主要有以下兩種方式:

* ___cache___: 將 pipeline 運行過程中的檔案以壓縮方式存放在 `GitLab Runner` (也就是說要使用 tag 指定 gitlab-runner 才可以使用先前上傳的檔案)
  * 被設計用來暫時存放 project 相依的套件, 讓隨後運行的 job 不用再從 internet 下載一次,  其目的為降低持續整合所需的時間
  * 同 pipeline 下次可以依據 key 來找到先前緩存的檔案.
  * 同 pipeline 後續 job 可以依據 key 來找到先前緩存的檔案.
  * 不同 project 不能共用 cache
  * 每個 job 都可以有自己的 cahce

* ___artifacts___: 將 Job 運行過程中的檔案以壓縮方式存放在遠端 `GitLab Server` 上, 讓不同的 stages 可以獲取先前 stage 產生的檔案, 其目的為解決持續整合過程間檔案相依的問題, 另外我們也可以從 GitLab server [下載 artifacts](https://docs.gitlab.com/ee/ci/pipelines/job_artifacts.html#download-job-artifacts)
  * `只能在 job 中去定義 artifacts, 而不是 global`.
  * 同 pipeline 後續 job 可以使用 artifacts.
  * 不同 project 不能共用 artifacts.
  * 在 [.gitlab-ci.yml](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci.yml) 的 job 中使用 `artifacts` 儲存檔案, 並在隨後的 job 使用 `dependencies` 取得檔案.
  * Artifacts 預設為 30天後過期. ([可自行定義](https://docs.gitlab.com/ee/user/admin_area/settings/continuous_integration.html#default-artifacts-expiration))
  * 如果 keep latest artifacts is enabled, 最新的 artifacts 將不會過期.

artifacts 和 caches 中定義的 paths 都是相對於 project 目錄.

## Use Docker-in-Docker with privileged mode

Docker containers 預設為 `unprivileged` 模式, 所以 container 不允許存取任何 devices. 但是 `privileged` container 具有存取所有 devices 的權限, 為了在 Docker-in-Docker 的情境下能存取 docker daemon, 所以我們必須啟用 `privileged` 模式.

當使用 ___docker run --privileged___ 指令時, Docker 將會啟用啟用 `privileged` 模式, 但是我選擇設定在 [config.toml](https://github.com/ShungYang/gitlab/blob/master/config.toml) 中, 讓 privileged flag 會被套用到 build container 和 services 中.

## Docker-in-Docker with TLS disabled in the Docker executor

可以參考 [config.toml](https://github.com/ShungYang/gitlab/blob/master/config.toml) 和 [.gitlab-ci.yml](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci.yml) 的設定方式來關閉 TLS

## Limitations of Docker-in-Docker

* docker-compose : 預設無法使用 docker-compose 的指令. 要用的話可以進一步[安裝](https://docs.docker.com/compose/install/).
* Cache: 每一個 job 都是在自己的容器中運行並不會互相的影響, 但是各 jobs 之間 build 的過程會相對慢, 因為沒有 caching of layers, 官方有提到可以用 [--cache-from](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#make-docker-in-docker-builds-faster-with-docker-layer-caching) 來加速

## Reference Link

* [How to Build Docker Images In a GitLab CI Pipeline](https://www.cloudsavvyit.com/15115/how-to-build-docker-images-in-a-gitlab-ci-pipeline/) by JAMES WALKER
* [How to Start a Docker Container Inside your GitLab CI pipeline](https://medium.com/devops-with-valentine/how-to-start-a-docker-container-inside-your-gitlab-ci-pipeline-bfeb610c3f4) by Valentin Despa
* [Best practices for building docker images with GitLab CI](https://blog.callr.tech/building-docker-images-with-gitlab-ci-best-practices/) by Callr Tech Blog
* [Using Docker-in-Docker for your CI or testing environment? Think twice.](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/) by Jérôme Petazzoni
* [Docker in Docker?](https://itnext.io/docker-in-docker-521958d34efd) by Daniel Weibel

__Enjoy!__

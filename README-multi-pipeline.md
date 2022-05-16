# Multi-project Pipeline

> You can set up GitLab CI/CD across multiple projects, so that a pipeline in one project can trigger a pipeline in another project. You can visualize the entire pipeline in one place, including all cross-project interdependencies.

大致上會使用到 ___Multi-project Pipeline___ 的情境有以下幾個:

* 針對一個大型專案來說會包含底下其他專案, 所以在 CI/CD pipeline 的過程同樣也會一併的讓其他相依的專案一起執行 CI/CD pipeline.

* 對於 Kubernetes 的服務來說一定會有 source code 和 yaml 配置文件兩個部分, 而 GitOps 的最佳實踐告訴我們應該分別有 code git project 作原始碼的版控和 manifest git project 保存 yaml 配置文件 (或是 Helm chart, kustomize), 這樣的原因是:
  * 職責區分, 而且通常開發人員只有原始碼的進版權限 (code git project), 維運人員才有服務佈署的權限 (manifest git project).
  * 如果今天只是要修改 yaml 文件中 deployment 的 replicaset 數量作修改, 那原始碼不應該再進行 rebuild.

## Deploy service by helm chart

我要在 CI/CD pipeline 中使用 helm chart 佈署服務到 K8s 的群集中, 根據 GitOps 的最佳實踐我建立了兩個專案

* ___Code git project___: [demo-code](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci-code.yml).
* ___Manifest git project___: [demo-manifest](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci-manifest.yml).

並且在 demo-code pipeline 中建立一個 bridge-job `trigger` demo-manifest pipeline 的運行, 同時還會將變數傳遞到 demo-manifest pipeline, 這樣的上下關係我們會稱 demo-code pipeline 為 ___upperstream___, demo-manifest pipeline 為 ___downstream___.

## Upperstream [gitlab-ci.yaml](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci-code.yml)

* 使用 trigger 關鍵字透過 `project` keyword 去指定要觸發的 pipeline full path, 也可以加上 `branch` keyword 指名.

* 使用 variables 關鍵字宣告要傳遞到 downstream pipeline 的變數.

## Downstream [gitlab-ci.yaml](https://github.com/ShungYang/gitlab/blob/master/.gitlab-ci-manifest.yml)

需要梳理的要點比較多,

* 當一個 downstream pipeline 被 triggered 時, 可以在 `workflow` keyword 配上 `rule` keyword 來控制 pipeline 的行為, 我的例子是要求只能由 demo-code project 的 pipeline 進行觸發, 而 `$CV_UPPSTREAM_PRJ_NAME` 是在 upperstream 中宣告的作為指定 pipeline name 觸發的判斷.

* 根據使用的情境不同也可以在 job 使用 `rule` keyword 和 `only` keyword 來決定 job 是否運行.

* 由於我定義所有的 jobs 都會執行在同一個 shell executor (host) 上, 所以可以忽略掉不同 job 會被分配到不同 shell executor, 而造成擋案需要透過 artifacts 來跨 jobs 傳遞的問題.

* 定義的 job: edit-chart 用途在於將 Upperstream 傳遞過來的 image tag 更新到 Helm chart values.yaml 中, 如果是 kustomize 可以使用 `kustomize edit set image` 輕鬆完成, 但是 Helm chart 似乎沒有類似的語法 (所以我這邊留著 TO-DO 須要靠別的方式實作), 取而代之的是直接透過參數 override value, 這樣一來 values.yaml 中的 image tag 就不會有版本記錄. (其實也可以在 helm install 的時候傳遞版本和 description 參數進來, 這樣 release 上仍然可以看到版本資訊).

* shell executor 運行 script 的身分都是 gitab-runner 所以要注意權限的問題.

## Reference Link

* [Multi-project pipelines](https://docs.gitlab.com/ee/ci/pipelines/multi_project_pipelines.html)
* [Configure CI/CD jobs to run in triggered pipelines](https://docs.gitlab.com/ee/ci/triggers/)

__Enjoy!__

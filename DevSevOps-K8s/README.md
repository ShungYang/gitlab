# DevSecOps - 佈署服務至 Kubernetes Cluser

__分為兩個 Gitlab project, 一個是 [Code Repository]() 針對服務程式碼進行版控, 另一個是 [Manifest Repository]() 用來對我們的 K8s YAML Configuration 進行版控__. 那為什麼針對要佈署到 K8s Cluster 的服務, 我們需要拆分兩個 Repository 來做版控主要的原因是 _職責分離_, 所帶來的好處如下:

## Separating Manifest Vs. Source Code Repositories

* 當我們只是要對 manifests 的設定做修改, 此時並不涉及程式碼的邏輯修改自然不用去重新執行整個 CI Build 的動作, 例如 Deployment.replicaCount 的數量, 或是調整 Label.

* 各自擁有 Commit log, Pipeline log 對於檢視歷史記錄及追蹤可以更清晰.

* 開發人員專注於程式碼的邏輯, 維運人員或是 Infra 人員可以只在乎環境設定檔是否正確, 還可以針對兩個 Repository 設定不同的 Member, 可以更好的規範角色存取權限.

## DevOps + Security = DevSecOps

* DevOps
  * SourceCode Version Control(SVC) : `git`.
  * SVC Platform : `Gitlab CE`
  * CI/CD Pipeline Tool : `Gitlab Runner`
* Security : [SonarQube]()

## Code Repository Guide

* 開發人員 push "DEV" 時觸發 `DEV pipeline`.
  1. variables : 使用 yq - YAML Processor 來解析 gitlab-ci-variables.yml 中的變數, 並存在 artifacts.reports.dotenv, 讓後來相依的 job 取用.
  2. build-scan : Build [Dockefile]() 並且使用 SonarScanner 執行 Static Code Analysis.
  3. test : 可規劃 job 同時執行數個測試作業包含單元測試, 壓力測試, UI 測試.
  4. publish : 如果先前的安全性分析及測試都通過後, 將 build-scan stage 打包好的 docker image 發佈到 Nexus server 上.
  5. trigger : 用來觸發 `Manifest Repository` Pipeline.
     * Clone Manifest repo
     * Modify YAMLs
     * Push to Manifest repo.

* Apply `Merge Request` "DEV" into "main"
  * 部門主管確認沒問題按下 Approve 後透過 Gitlab 發通知信給 SQA

* SQA 在檢查完上線的相關文件後按下 Merge 會觸發 `main pipeline`.
  1. build-scan
  2. publish
  3. trigger : 用來觸發 `Manifest Repository` Pipeline.
     * 使用 Gitlab API 觸發 Manifest Repository 的 Merge Request.

## Manifest Repository Guide

__預設 Pipeline 皆透過 `Code Repository` 觸發__.

* 由 `Code Repository` push "DEV" 時觸發 `DEV pipeline` 執行 :
  * deploy
* 由 `Code Repository` 透過 Gitlab API 發起了 `Merge Request` 後等待上線時間到了 SQA 即可按下 Merge 作一鍵佈署
* SQA 按下 Merge 會觸發 main pipeline 執行
  1. publish
     * Modify helm chart
     * Package helm chart
     * Publish to Nexus server
  2. deploy

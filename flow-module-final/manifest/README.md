# flowmodule-manifest

WebAPI FlowModule YAML


## 前置步驟

* 建立 hou-fa-namespace (Option)

```sh
kubectl create namespace hou-fa-namespace
```

* 檢查是否成功

```sh
kubectl get namespace
```

* 或是修改 values.yaml 中的 namespace 屬性改為 infra 配置好的 namespace

* 因為簽核模組的 docker image 會發佈到 Nexus server 上, 所以要確認同一個 namespace 中有存在 nexus-registry-secret.

* `之後移轉到 OpenShift 時會有新的 registry, 所以會有新的 registry-secret, 記得要修改 values.yaml 的 imagePullSecrets 屬性`.

```sh
kubectl apply -f /home/osadmin/shawn/flow-module/nexus-secret.yaml
```

* 檢查是否成功

```sh
kubectl get secret -n hou-fa-namespace
```

以上的資源如果都已經存在, 那就不用重複建立

* 修改 Chart.yaml 的屬性
    * description : 這次改版的敘述
    * version : 版本號格式 x.x.x
    * appVersion : `docker image 的 tag`

## helm deploy flow-module

* 切換 namespace

```sh
kubectl config set-context --current --namespace=hou-fa-namespace
```

* 列出當前 namespace 有哪些運行的 helm release

```sh
helm list
```

* 確認 helm chart 內容是否正確

```sh
helm template flow-module ./charts/flow-module --set deploy.env.mode=prod --description="Phase II (Reject to, SINGLE -> ANY, Access Token)" --debug
```

* Upgrade or install chart to 正式區

```sh
helm upgrade flow-module ./charts/flow-module --set deploy.env.mode=prod --description="Phase II (Reject to, SINGLE -> ANY, Access Token)" --install --debug
```

* 退回指定版本, 會新增一個 Revision 但是 App 版本會更改為指定的 `REVISION`

```sh
helm rollback flow-module [REVISION]
```

* 解除安裝

```sh
helm uninstall flow-module
```

更多指令可以參考官網 [文件](https://helm.sh/docs/helm/helm/)
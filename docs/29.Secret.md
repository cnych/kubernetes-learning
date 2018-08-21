# Secret

上节课我们学习了`ConfigMap`的时候，我们说`ConfigMap`这个资源对象是`Kubernetes`当中非常重要的一个对象，一般情况下`ConfigMap`是用来存储一些非安全的配置信息，如果涉及到一些安全相关的数据的话用`ConfigMap`就非常不妥了，因为`ConfigMap`是名为存储的，我们说这个时候我们就需要用到另外一个资源对象了：`Secret`，`Secret`用来保存敏感信息，例如密码、OAuth 令牌和 ssh key等等，将这些信息放在`Secret`中比放在`Pod`的定义中或者`docker`镜像中来说更加安全和灵活。


`Secret`有三种类型： 

* Opaque：base64 编码格式的 Secret，用来存储密码、密钥等；但数据也可以通过base64 –decode解码得到原始数据，所有加密性很弱。 
* kubernetes.io/dockerconfigjson：用来存储私有docker registry的认证信息。 
* kubernetes.io/service-account-token：用于被`serviceaccount`引用，serviceaccout 创建时Kubernetes会默认创建对应的secret。Pod如果使用了serviceaccount，对应的secret会自动挂载到Pod目录`/run/secrets/kubernetes.io/serviceaccount`中。


## Opaque Secret
Opaque 类型的数据是一个 map 类型，要求value是`base64`编码格式，比如我们来创建一个用户名为 admin，密码为 admin321 的 Secret 对象，首先我们先把这用户名和密码做 base64 编码，
```shell
$ echo -n "admin" | base64
YWRtaW4=
$ echo -n "admin321" | base64
YWRtaW4zMjE=
```

然后我们就可以利用上面编码过后的数据来编写一个`YAML`文件：(secret-demo.yaml)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=
  password: YWRtaW4zMjE=
```

然后同样的我们就可以使用`kubectl`命令来创建了：
```shell
$ kubectl create -f secret-demo.yaml
secret "mysecret" created
```

利用`get secret`命令查看：
```shell
$ kubectl get secret
NAME                  TYPE                                  DATA      AGE
default-token-n9w2d   kubernetes.io/service-account-token   3         33d
mysecret              Opaque                                2         40s
```

> 其中`default-token-cty7pdefault-token-n9w2d`为创建集群时默认创建的 secret，被serviceacount/default 引用。

使用`describe`命令，查看详情：
```shell
$ kubectl describe secret mysecret
Name:         mysecret
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
password:  8 bytes
username:  5 bytes
```
我们可以看到利用`describe`命令查看到的`Data`没有直接显示出来，如果想看到`Data`里面的详细信息，同样我们可以输出成`YAML`文件进行查看：
```shell
$ kubectl get secret mysecret -o yaml
apiVersion: v1
data:
  password: YWRtaW4zMjE=
  username: YWRtaW4=
kind: Secret
metadata:
  creationTimestamp: 2018-06-19T15:27:06Z
  name: mysecret
  namespace: default
  resourceVersion: "3694084"
  selfLink: /api/v1/namespaces/default/secrets/mysecret
  uid: 39c139f5-73d5-11e8-a101-525400db4df7
type: Opaque
```

创建好`Secret`对象后，有两种方式来使用它：

* 以环境变量的形式
* 以Volume的形式挂载


### 环境变量
首先我们来测试下环境变量的方式，同样的，我们来使用一个简单的`busybox`镜像来测试下:(secret1-pod.yaml)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret1-pod
spec:
  containers:
  - name: secret1
    image: busybox
    command: [ "/bin/sh", "-c", "env" ]
    env:
    - name: USERNAME
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: username
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: password
```

主要上面环境变量中定义的`secretKeyRef`关键字，和我们上节课的`configMapKeyRef`是不是比较类似，一个是从`Secret`对象中获取，一个是从`ConfigMap`对象中获取，创建上面的`Pod`：
```shell
$ kubectl create -f secret1-pod.yaml
pod "secret1-pod" created
```

然后我们查看`Pod`的日志输出：
```shell
$ kubectl logs secret1-pod
...
USERNAME=admin
PASSWORD=admin321
...
```
可以看到有 USERNAME 和 PASSWORD 两个环境变量输出出来。


### Volume 挂载
同样的我们用一个`Pod`来验证下`Volume`挂载，创建一个`Pod`文件：(secret2-pod.yaml)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret2-pod
spec:
  containers:
  - name: secret2
    image: busybox
    command: ["/bin/sh", "-c", "ls /etc/secrets"]
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
  volumes:
  - name: secrets
    secret:
     secretName: mysecret
```

创建`Pod`:
```shell
$ kubectl create -f secret-pod2.yaml
pod "secret2-pod" created
```

然后我们查看输出日志：
```shell
$ kubectl logs secret2-pod
password
username
```
可以看到`secret`把两个key挂载成了两个对应的文件。当然如果想要挂载到指定的文件上面，是不是也可以使用上一节课的方法：在`secretName`下面添加`items`指定 key 和 path，这个大家可以参考上节课`ConfigMap`中的方法去测试下。


## kubernetes.io/dockerconfigjson
除了上面的`Opaque`这种类型外，我们还可以来创建用户`docker registry`认证的`Secret`，直接使用`kubectl create`命令创建即可，如下：
```shell
$ kubectl create secret docker-registry myregistry --docker-server=DOCKER_SERVER --docker-username=DOCKER_USER --docker-password=DOCKER_PASSWORD --docker-email=DOCKER_EMAIL
secret "myregistry" created
```

然后查看`Secret`列表：
```shell
$ kubectl get secret
NAME                  TYPE                                  DATA      AGE
default-token-n9w2d   kubernetes.io/service-account-token   3         33d
myregistry            kubernetes.io/dockerconfigjson        1         15s
mysecret              Opaque                                2         34m
```
注意看上面的`TYPE`类型，`myregistry`是不是对应的`kubernetes.io/dockerconfigjson`，同样的可以使用`describe`命令来查看详细信息：
```shell
$ kubectl describe secret myregistry
Name:         myregistry
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  kubernetes.io/dockerconfigjson

Data
====
.dockerconfigjson:  152 bytes
```

同样的可以看到`Data`区域没有直接展示出来，如果想查看的话可以使用`-o yaml`来输出展示出来：
```shell
$ kubectl get secret myregistry -o yaml
apiVersion: v1
data:
  .dockerconfigjson: eyJhdXRocyI6eyJET0NLRVJfU0VSVkVSIjp7InVzZXJuYW1lIjoiRE9DS0VSX1VTRVIiLCJwYXNzd29yZCI6IkRPQ0tFUl9QQVNTV09SRCIsImVtYWlsIjoiRE9DS0VSX0VNQUlMIiwiYXV0aCI6IlJFOURTMFZTWDFWVFJWSTZSRTlEUzBWU1gxQkJVMU5YVDFKRSJ9fX0=
kind: Secret
metadata:
  creationTimestamp: 2018-06-19T16:01:05Z
  name: myregistry
  namespace: default
  resourceVersion: "3696966"
  selfLink: /api/v1/namespaces/default/secrets/myregistry
  uid: f91db707-73d9-11e8-a101-525400db4df7
type: kubernetes.io/dockerconfigjson
```

可以把上面的`data.dockerconfigjson`下面的数据做一个`base64`解码，看看里面的数据是怎样的呢？
```shell
$ echo eyJhdXRocyI6eyJET0NLRVJfU0VSVkVSIjp7InVzZXJuYW1lIjoiRE9DS0VSX1VTRVIiLCJwYXNzd29yZCI6IkRPQ0tFUl9QQVNTV09SRCIsImVtYWlsIjoiRE9DS0VSX0VNQUlMIiwiYXV0aCI6IlJFOURTMFZTWDFWVFJWSTZSRTlEUzBWU1gxQkJVMU5YVDFKRSJ9fX0= | base64 -d
{"auths":{"DOCKER_SERVER":{"username":"DOCKER_USER","password":"DOCKER_PASSWORD","email":"DOCKER_EMAIL","auth":"RE9DS0VSX1VTRVI6RE9DS0VSX1BBU1NXT1JE"}}}
```

如果我们需要拉取私有仓库中的`docker`镜像的话就需要使用到上面的`myregistry`这个`Secret`：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: foo
spec:
  containers:
  - name: foo
    image: 192.168.1.100:5000/test:v1
  imagePullSecrets:
  - name: myregistrykey
```
我们需要拉取私有仓库镜像`192.168.1.100:5000/test:v1`，我们就需要针对该私有仓库来创建一个如上的`Secret`，然后在`Pod`的 YAML 文件中指定`imagePullSecrets`，我们会在后面的私有仓库搭建的课程中跟大家详细说明的。


## kubernetes.io/service-account-token
另外一种`Secret`类型就是`kubernetes.io/service-account-token`，用于被`serviceaccount`引用。serviceaccout 创建时 Kubernetes 会默认创建对应的 secret。Pod 如果使用了 serviceaccount，对应的secret会自动挂载到Pod的`/run/secrets/kubernetes.io/serviceaccount`目录中。

这里我们使用一个`nginx`镜像来验证一下，大家想一想为什么不是呀`busybox`镜像来验证？当然也是可以的，但是我们就不能在`command`里面来验证了，因为token是需要`Pod`运行起来过后才会被挂载上去的，直接在`command`命令中去查看肯定是还没有 token 文件的。

```shell
$ kubectl run secret-pod3 --image nginx:1.7.9
deployment.apps "secret-pod3" created
$ kubectl get pods
NAME                           READY     STATUS    RESTARTS   AGE
...
secret-pod3-78c8c76db8-7zmqm   1/1       Running   0          13s
...
$ kubectl exec secret-pod3-78c8c76db8-7zmqm ls /run/secrets/kubernetes.io/serviceaccount
ca.crt
namespace
token
$ kubectl exec secret-pod3-78c8c76db8-7zmqm cat /run/secrets/kubernetes.io/serviceaccount/token
eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImRlZmF1bHQtdG9rZW4tbjl3MmQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGVmYXVsdCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjMzY2FkOWQxLTU5MmYtMTFlOC1hMTAxLTUyNTQwMGRiNGRmNyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmRlZmF1bHQifQ.0FpzPD8WO_fwnMjwpGIOphdVu4K9wUINwpXpBOJAQ-Tawd0RTbAUHcgYy3sEHSk9uvgnl1FJRQpbQN3yVR_DWSIlAtbmd4dIPxK4O7ZVdd4UnmC467cNXEBqL1sDWLfS5f03d7D1dw1ljFJ_pJw2P65Fjd13reKJvvTQnpu5U0SDcfxj675-Z3z-iOO3XSalZmkFIw2MfYMzf_WpxW0yMFCVkUZ8tBSTegA9-NJZededceA_VCOdKcUjDPrDo-CNti3wZqax5WPw95Ou8RJDMAIS5EcVym7M2_zjGiqHEL3VTvcwXbdFKxsNX-1VW6nr_KKuMGKOyx-5vgxebl71QQ
```



## Secret 与 ConfigMap 对比
最后我们来对比下`Secret`和`ConfigMap`这两种资源对象的异同点：

相同点： 
- key/value的形式 
- 属于某个特定的namespace 
- 可以导出到环境变量 
- 可以通过目录/文件形式挂载
- 通过 volume 挂载的配置信息均可热更新

不同点： 
- Secret 可以被 ServerAccount 关联
- Secret 可以存储 docker register 的鉴权信息，用在 ImagePullSecret 参数中，用于拉取私有仓库的镜像 
- Secret 支持 Base64 加密 
- Secret 分为  kubernetes.io/service-account-token、kubernetes.io/dockerconfigjson、Opaque 三种类型，而 Configmap 不区分类型

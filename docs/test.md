# 44. Helm 模板使用
上节课和大家一起学习了`Helm`的一些常用操作方法，这节课来和大家一起定义一个`chart`包，了解 Helm 中模板的使用方法。


## 定义 chart
Helm 的 github 上面有一个比较[完整的文档](https://github.com/kubernetes/helm/blob/master/docs/charts.md)，建议大家好好阅读下该文档，这里我们来一起创建一个`chart`包。

一个 chart 包就是一个文件夹的集合，文件夹名称就是 chart 包的名称，比如创建一个 hello-world 的 chart 包：
```shell
$ mkdir ./hello-world
$ cd hello-world
```

chart 必须包含定义文件`Chart.yaml`文件，定义文件必须定义两个属性：`name`和`version`(Semantic Versioning 2):
```shell
$ cat <<'EOF' > ./Chart.yaml
name: hello-world
version: 1.0.0
EOF
```

一个 chart 包必须定义用来生成`kubernetes`资源对象的模板文件，这些模板文件定义在 templates 目录下面，这里我们来尝试使用 helm 自定义一个 nginx 服务：
```shell
$ mkdir ./templates
$ cat <<'EOF' > ./templates/deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
        - name: hello-world
          image: nginx:1.7.9
          ports:
            - containerPort: 80
              protocol: TCP
EOF
$ cat <<'EOF' > ./templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: hello-world
EOF
```

上面我们定义的模板是最终一个`release`实例需要运行的资源对象，一个`Deployment`对象，一个`Service`对象，也是以前我们运行一个 nginx 服务需要的两个资源对象。

## 配置 release
上节课我们学习了管理一个 release 整个生命周期的一些方法，install、rollback、upgrade 以及 delete 等等操作，但是仅仅这些命令还不够，我们还需要一些工具来管理`release`。

Helm Chart 模板使用的是[`Go`语言模板](https://golang.org/pkg/text/template/)编写而成，并添加了[`Sprig`库](https://github.com/Masterminds/sprig)中的50多个附件模板函数以及一些其他[特殊的函](https://github.com/kubernetes/helm/blob/master/docs/charts_tips_and_tricks.md)。

模板的值通过`values.yaml`文件提供，现在我们来定义一个`values.yaml`文件，提供 image 镜像的仓库配置：
```shell
$ cat <<'EOF' > ./values.yaml
image:
  repository: nginx
  tag: 1.7.9
EOF
```

现在我们就可以通过模板中的`.Values`对象来访问`values.yaml`文件提供的值。比如我们将上面的`templates/deployment.yaml`文件中的`image`镜像地址通过`values.yaml`中的`image`对象来替换掉：
```shell
$ cat <<'EOF' > ./templates/deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
        - name: hello-world
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: 80
              protocol: TCP
EOF
```

## 调试
现在我们的模板文件已经定义好了，但是如果我们想要调试还是非常不方便的，不可能我们每次都去部署一个`release`实例来校验模板是否正确，为此 Helm 为我们提供了`--dry-run --debug`这个可选参数，在执行`helm install`的时候带上这两个参数就可以把对应的 values 值和生成的最终的资源清单文件打印出来，而不会真正的去部署一个`release`实例，比如我们来调试上面创建的 chart 包：
```shell
$ helm install . --dry-run --debug --set image.tag=latest
[debug] Created tunnel using local port: '38359'

[debug] SERVER: "127.0.0.1:38359"

[debug] Original chart version: ""
[debug] CHART PATH: /root/course/kubeadm/helm/hello-world

NAME:   calling-turkey
REVISION: 1
RELEASED: Fri Sep  7 23:57:45 2018
CHART: hello-world-1.0.0
USER-SUPPLIED VALUES:
image:
  tag: latest

COMPUTED VALUES:
image:
  repository: nginx
  tag: latest

HOOKS:
MANIFEST:

---
# Source: hello-world/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: hello-world
---
# Source: hello-world/templates/deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
        - name: hello-world
          image: nginx:latest
          ports:
            - containerPort: 80
              protocol: TCP
```

注意看上面的镜像地址已经被替换成了**nginx:latest**了，这是因为我们用`--set`参数把镜像的 tag 给覆盖掉了，而镜像名称已经被 values.yaml 中的内容替换掉了。

现在我们使用`--dry-run`就可以很容易地测试代码了，不需要每次都去安装一个 release 实例了，但是要注意的是这不能确保 Kubernetes 本身就一定会接受生成的模板，在调试完成后，还是需要去安装一个实际的 release 实例来进行验证的。


## 预定义值
除了使用用户定义的值外，Helm 还内置了许多预定义的值，我们可以在 [Helm 的文档中进行查看]((https://github.com/kubernetes/helm/blob/master/docs/charts.md#predefined-values)，比如chang'y常用的有：

* .Release，这个对象描述了 release 本身，提供了比如：.Release.Name(release 名称)、.Release.Time(release 的时间)
* .Chart，表示`Chart.yaml`文件的内容。所有的 Chart 对象都将从该文件中访问。chart 指南中[Charts Guide](https://github.com/kubernetes/helm/blob/master/docs/charts.md#the-chartyaml-file)列出了可用字段，可以前往查看。
* Files：用于引用 Chart 目录中的其他文件。

现在我们来使用预定义的值给上面的资源文件定义一些标签，让我们可以很方便的识别出资源：
```shell
$ cat <<'EOF' > ./templates/deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
  labels:
    app: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
    version: {{ .Chart.Version }}
    release: {{ .Release.Name }}
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
        version: {{ .Chart.Version }}
        release: {{ .Release.Name }}
    spec:
      containers:
        - name: hello-world
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: 80
              protocol: TCP
EOF
$ cat <<'EOF' > ./templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
  labels:
    app: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
    version: {{ .Chart.Version }}
    release: {{ .Release.Name }}
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
EOF
```

我们这里使用`.Release.Name`并上`.Chart.Name`来做为资源的名称：
```
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
```

这里我们加上了一个63个字符的截断，这是因为`kubernetes`资源对象的 labels 和 name 定义被[限制为 63个字符](http://kubernetes.io/docs/user-guide/labels/#syntax-and-character-set)，所以需要注意名称的定义长度。


## 模板引用
我们上面定义的模板文件中，可能有的人已经发现了，我们的 labels 定义以及资源名称的定义很多都是重复的：
```yaml
app: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
version: {{ .Chart.Version }}
release: {{ .Release.Name }}
```

我们在 Deployment、Pod、Service 资源对象中都定义了3个相同的 label 标签，而资源名称都是一个比较长的表达式：
```yaml
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
```

如果应用程序非常复杂的话，这种重复的属性就更多了，这显然不是一种很好的方式，如果我们去掉这些 label 标签呢？当然可以，但是这对于资源对象的辨别就会显得困难了。这里我们可以定义一些模板文件来进行引用，就可以很好的解决这个问题。

创建一个`_helpers.tpl`文件用来声明模板中的一部分内容：

> 主意：./templates 目录中已`_`开头的文件不会被看做 kubernetes 的资源清单文件，这些文件不会被发送到 kubernetes 中去。

```shell
$ cat <<'EOF'> ./templates/_helpers.tpl
{{- define "hello-world.release_labels" }}
app: {{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 }}
version: {{ .Chart.Version }}
release: {{ .Release.Name }}
{{- end }}

{{- define "hello-world.full_name" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 -}}
{{- end -}}
EOF
```

上面的文件中我们就定义了两个模块：**hello-world.release_labels**和**hello-world.full_name**，这两个模块都可以在模板中进行使用：

> 模板名称都是全局的。由于子 chart 中的模板与顶级模板一起编译，所以需要注意 chart 的命名，这也是为什么

```shell
$ cat <<'EOF' > ./templates/deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: {{ template "hello-world.full_name" . }}
  labels:
    {{- include "hello-world.release_labels" . | indent 4 }}
spec:
  replicas: 1
  template:
    metadata:
      labels:
        {{- include "hello-world.release_labels" . | indent 8 }}
    spec:
      containers:
        - name: hello-world
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: 80
              protocol: TCP
EOF
$ cat <<'EOF' > ./templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ template "hello-world.full_name" . }}
  labels:
    {{- include "hello-world.release_labels" . | indent 4 }}
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: {{ template "hello-world.full_name" . }}
EOF
```
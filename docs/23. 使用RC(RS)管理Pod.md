## 使用Replication Controller、Replica Set 管理Pod

前面我们的课程中学习了`Pod`的一些基本使用方法，而且前面我们都是直接来操作的`Pod`，假如我们现在有一个`Pod`正在提供线上的服务，我们来想想一下我们可能会遇到的一些场景：

* 某次运营活动非常成功，网站访问量突然暴增
* 运行当前`Pod`的节点发生故障了，`Pod`不能正常提供服务了

第一种情况，可能比较好应对，一般活动之前我们会大概计算下会有多大的访问量，提前多启动几个`Pod`，活动结束后再把多余的`Pod`杀掉，虽然有点麻烦，但是应该还是能够应对这种情况的。

第二种情况，可能某天夜里收到大量报警说服务挂了，然后起来打开电脑在另外的节点上重新启动一个新的`Pod`，问题也很好的解决了。

如果我们都人工的去解决遇到的这些问题，似乎又回到了以前刀耕火种的时代了是吧，如果有一种工具能够来帮助我们管理`Pod`就好了，`Pod`不够了自动帮我新增一个，`Pod`挂了自动帮我在合适的节点上重新启动一个`Pod`，这样是不是遇到上面的问题我们都不需要手动去解决了。

幸运的是，`Kubernetes`就为我们提供了这样的资源对象：

* Replication Controller：用来部署、升级`Pod`
* Replica Set：下一代的`Replication Controller`
* Deployment：可以更加方便的管理`Pod`和`Replica Set`


### Replication Controller（RC）
`Replication Controller`简称`RC`，`RC`是`Kubernetes`系统中的核心概念之一，简单来说，`RC`可以保证在任意时间运行`Pod`的副本数量，能够保证`Pod`总是可用的。如果实际`Pod`数量比指定的多那就结束掉多余的，如果实际数量比指定的少就新启动一些`Pod`，当`Pod`失败、被删除或者挂掉后，`RC`都会去自动创建新的`Pod`来保证副本数量，所以即使只有一个`Pod`，我们也应该使用`RC`来管理我们的`Pod`。

我们想想如果现在我们遇到上面的问题的话，可能除了第一个不能做到完全自动化，其余的我们是不是都不用担心了，运行`Pod`的节点挂了，`RC`检测到`Pod`失败了，就会去合适的节点重新启动一个`Pod`就行，不需要我们手动去新建一个`Pod`了。如果是第一种情况的话在活动开始之前我们给`Pod`指定10个副本，结束后将副本数量改成2，这样是不是也远比我们手动去启动、手动去关闭要好得多，而且我们后面还会给大家介绍另外一种资源对象`HPA`可以根据资源的使用情况来进行自动扩缩容，这样以后遇到这种情况，我们就真的可以安心的去睡觉了。

现在我们来使用`RC`来管理我们前面使用的`Nginx`的`Pod`，`YAML`文件如下：
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: rc-demo
  labels:
    name: rc
spec:
  replicas: 3
  selector:
    name: rc
  template:
    metadata:
     labels:
       name: rc
    spec:
     containers:
     - name: nginx-demo
       image: nginx
       ports:
       - containerPort: 80
```

上面的`YAML`文件相对于我们之前的`Pod`的格式：

* kind：`ReplicationController`
* spec.replicas: 指定`Pod`副本数量，默认为1
* spec.selector: `RC`通过该属性来筛选要控制的`Pod`
* spec.template: 这里就是我们之前的`Pod`的定义的模块，但是不需要`apiVersion`和`kind`了
* spec.template.metadata.labels: 注意这里的`Pod`的`labels`要和`spec.selector`相同，这样`RC`就可以来控制当前这个`Pod`了。

这个`YAML`文件中的意思就是定义了一个`RC`资源对象，它的名字叫`rc-demo`，保证一直会有3个`Pod`运行，`Pod`的镜像是`nginx`镜像。

> 注意`spec.selector`和`spec.template.metadata.labels`这两个字段必须相同，否则会创建失败的，当然我们也可以不写`spec.selector`，这样就默认与`Pod`模板中的`metadata.labels`相同了。所以为了避免不必要的错误的话，不写为好。

然后我们来创建上面的`RC`对象(保存为 rc-demo.yaml):
```shell
$ kubectl create -f rc-demo.yaml
```

查看`RC`：
```shell
$ kubectl get rc
```

查看具体信息：
```shell
$ kubectl describe rc rc-demo
```

然后我们通过`RC`来修改下`Pod`的副本数量为2：
```shell
$ kubectl apply -f rc-demo.yaml
```
或者
```shell
$ kubectl edit rc rc-demo
```

而且我们还可以用`RC`来进行滚动升级，比如我们将镜像地址更改为`nginx:1.7.9`:
```shell
$ kubectl rolling-update rc-demo --image=nginx:1.7.9
```
但是如果我们的`Pod`中多个容器的话，就需要通过修改`YAML`文件来进行修改了:
```shell
$ kubectl rolling-update rc-demo -f rc-demo.yaml
```
如果升级完成后出现了新的问题，想要一键回滚到上一个版本的话，使用`RC`只能用同样的方法把镜像地址替换成之前的，然后重新滚动升级。


### Replication Set（RS）
`Replication Set`简称`RS`，随着`Kubernetes`的高速发展，官方已经推荐我们使用`RS`和`Deployment`来代替`RC`了，实际上`RS`和`RC`的功能基本一致，目前唯一的一个区别就是`RC`只支持基于等式的`selector`（env=dev或environment!=qa），但`RS`还支持基于集合的`selector`（version in (v1.0, v2.0)），这对复杂的运维管理就非常方便了。

`kubectl`命令行工具中关于`RC`的大部分命令同样适用于我们的`RS`资源对象。不过我们也很少会去单独使用`RS`，它主要被`Deployment`这个更加高层的资源对象使用，除非用户需要自定义升级功能或根本不需要升级`Pod`，在一般情况下，我们推荐使用`Deployment`而不直接使用`Replica Set`。

最后我们总结下关于`RC`/`RS`的一些特性和作用吧：

* 大部分情况下，我们可以通过定义一个`RC`实现的`Pod`的创建和副本数量的控制
* `RC`中包含一个完整的`Pod`定义模块（不包含`apiversion`和`kind`）
* `RC`是通过`label selector`机制来实现对`Pod`副本的控制的
* 通过改变`RC`里面的`Pod`副本数量，可以实现`Pod`的扩缩容功能
* 通过改变`RC`里面的`Pod`模板中镜像版本，可以实现`Pod`的滚动升级功能（但是不支持一键回滚，需要用相同的方法去修改镜像地址）


好，这节课我们就给大家介绍了使用`RC`或者`RS`来管理我们的`Pod`，我们下节课来给大家介绍另外一种更加高级也是现在推荐使用的一个资源对象`Deployment`。


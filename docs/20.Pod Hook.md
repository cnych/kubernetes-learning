# Pod Hook

我们知道`Pod`是`Kubernetes`集群中的最小单元，而 Pod 是有容器组组成的，所以在讨论 Pod 的生命周期的时候我们可以先来讨论下容器的生命周期。

实际上 Kubernetes 为我们的容器提供了生命周期钩子的，就是我们说的`Pod Hook`，Pod Hook 是由 kubelet 发起的，当容器中的进程启动前或者容器中的进程终止之前运行，这是包含在容器的生命周期之中。我们可以同时为 Pod 中的所有容器都配置 hook。

Kubernetes 为我们提供了两种钩子函数：

* PostStart：这个钩子在容器创建后立即执行。但是，并不能保证钩子将在容器`ENTRYPOINT`之前运行，因为没有参数传递给处理程序。主要用于资源部署、环境准备等。不过需要注意的是如果钩子花费太长时间以至于不能运行或者挂起， 容器将不能达到`running`状态。
* PreStop：这个钩子在容器终止之前立即被调用。它是阻塞的，意味着它是同步的， 所以它必须在删除容器的调用发出之前完成。主要用于优雅关闭应用程序、通知其他系统等。如果钩子在执行期间挂起， Pod阶段将停留在`running`状态并且永不会达到`failed`状态。

如果`PostStart`或者`PreStop`钩子失败， 它会杀死容器。所以我们应该让钩子函数尽可能的轻量。当然有些情况下，长时间运行命令是合理的， 比如在停止容器之前预先保存状态。

另外我们有两种方式来实现上面的钩子函数：

* Exec - 用于执行一段特定的命令，不过要注意的是该命令消耗的资源会被计入容器。
* HTTP - 对容器上的特定的端点执行`HTTP`请求。


### 示例1 环境准备
以下示例中，定义了一个Nginx Pod，其中设置了`PostStart`钩子函数，即在容器创建成功后，写入一句话到`/usr/share/message`文件中。
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hook-demo1
spec:
  containers:
  - name: hook-demo1
    image: nginx
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo Hello from the postStart handler > /usr/share/message"]
```

### 示例2 优雅删除资源对象
当用户请求删除含有 pod 的资源对象时（如Deployment等），K8S 为了让应用程序优雅关闭（即让应用程序完成正在处理的请求后，再关闭软件），K8S提供两种信息通知：

* 默认：K8S 通知 node 执行`docker stop`命令，docker 会先向容器中`PID`为1的进程发送系统信号`SIGTERM`，然后等待容器中的应用程序终止执行，如果等待时间达到设定的超时时间，或者默认超时时间（30s），会继续发送`SIGKILL`的系统信号强行 kill 掉进程。
* 使用 pod 生命周期（利用`PreStop`回调函数），它执行在发送终止信号之前。

默认所有的优雅退出时间都在30秒内。kubectl delete 命令支持 `--grace-period=<seconds>`选项，这个选项允许用户用他们自己指定的值覆盖默认值。值'0'代表 强制删除 pod. 在 kubectl 1.5 及以上的版本里，执行强制删除时必须同时指定 `--force --grace-period=0`。

强制删除一个 pod 是从集群状态还有 etcd 里立刻删除这个 pod。 当 Pod 被强制删除时， api 服务器不会等待来自 Pod 所在节点上的 kubelet 的确认信息：pod 已经被终止。在 API 里 pod 会被立刻删除，在节点上， pods 被设置成立刻终止后，在强行杀掉前还会有一个很小的宽限期。

以下示例中，定义了一个Nginx Pod，其中设置了`PreStop`钩子函数，即在容器退出之前，优雅的关闭 Nginx:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hook-demo2
spec:
  containers:
  - name: hook-demo2
    image: nginx
    lifecycle:
      preStop:
        exec:
          command: ["/usr/sbin/nginx","-s","quit"]

---
apiVersion: v1
kind: Pod
metadata:
  name: hook-demo2
  labels:
    app: hook
spec:
  containers:
  - name: hook-demo2
    image: nginx
    ports:
    - name: webport
      containerPort: 80
    volumeMounts:
    - name: message
      mountPath: /usr/share/
    lifecycle:
      preStop:
        exec:
          command: ['/bin/sh', '-c', 'echo Hello from the preStop Handler > /usr/share/message']
  volumes:
  - name: message
    hostPath:
      path: /tmp
```

另外`Hook`调用的日志没有暴露个给 Pod 的 event，所以只能通过`describe`命令来获取，如果有错误将可以看到`FailedPostStartHook`或`FailedPreStopHook`这样的 event。

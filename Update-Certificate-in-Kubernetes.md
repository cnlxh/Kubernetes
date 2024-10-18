# Kubernetes 证书管理：更新与续订指南

```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

Kubernetes 集群的安全性在很大程度上依赖于其证书的有效管理。默认情况下，由 kubeadm 生成的客户端证书有效期为一年。随着时间的推移，这些证书可能会过期，从而影响集群的正常运行和安全性。因此，及时更新证书是维护集群安全的关键步骤，当然，如果你能每年至少更新一次集群，kubeadm能自动保持证书有效。

## 证书更新的必要性
- **安全性**：过期的证书可能导致安全漏洞，及时更新可以防止未授权访问。
- **稳定性**：证书过期可能导致集群组件无法正常通信，影响集群稳定性。
- **合规性**：某些组织可能需要遵守特定的安全标准，证书更新是满足这些标准的一部分。

## 检查证书有效性

在更新证书之前，首先需要检查现有证书的有效期。可以使用 kubeadm 提供的 `check-expiration` 子命令来实现这一点。

从下面的输出来看，证书在2025年的5月31日到期

```shell
kubeadm certs check-expiration
```
输出
```text

[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 May 31, 2025 01:02 UTC   301d            ca                      no
apiserver                  May 31, 2025 01:02 UTC   301d            ca                      no
apiserver-etcd-client      May 31, 2025 01:02 UTC   301d            etcd-ca                 no
apiserver-kubelet-client   May 31, 2025 01:02 UTC   301d            ca                      no
controller-manager.conf    May 31, 2025 01:02 UTC   301d            ca                      no
etcd-healthcheck-client    May 31, 2025 01:02 UTC   301d            etcd-ca                 no
etcd-peer                  May 31, 2025 01:02 UTC   301d            etcd-ca                 no
etcd-server                May 31, 2025 01:02 UTC   301d            etcd-ca                 no
front-proxy-client         May 31, 2025 01:02 UTC   301d            front-proxy-ca          no
scheduler.conf             May 31, 2025 01:02 UTC   301d            ca                      no
super-admin.conf           May 31, 2025 01:02 UTC   301d            ca                      no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      May 29, 2034 01:02 UTC   9y              no
etcd-ca                 May 29, 2034 01:02 UTC   9y              no
front-proxy-ca          May 29, 2034 01:02 UTC   9y              no
```

## 执行 kubeadm 证书更新

可以使用 `kubeadm certs renew` 命令来手动更新它们。此命令需要访问 CA 证书和相应的私钥，CA 证书 (ca.crt 和 ca.key) 通常存储在 `/etc/kubernetes/pki` 目录下，确保这些文件是可访问的

**如果你运行了一个 HA 集群，这个命令需要在所有控制节点上执行。**

更新特定证书例子：

```
kubeadm certs renew apiserver
```

更新所有证书例子：

```bash
kubeadm certs renew all
```
输出
```bash
[renew] Reading configuration from the cluster...
[renew] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'

certificate embedded in the kubeconfig file for the admin to use and for kubeadm itself renewed
certificate for serving the Kubernetes API renewed
certificate the apiserver uses to access etcd renewed
certificate for the API server to connect to kubelet renewed
certificate embedded in the kubeconfig file for the controller manager to use renewed
certificate for liveness probes to healthcheck etcd renewed
certificate for etcd nodes to communicate with each other renewed
certificate for serving etcd renewed
certificate for the front proxy client renewed
certificate embedded in the kubeconfig file for the scheduler manager to use renewed
certificate embedded in the kubeconfig file for the super-admin renewed

Done renewing certificates. You must restart the kube-apiserver, kube-controller-manager, kube-scheduler and etcd, so that they can use the new certificates.
```

## 更新管理凭据

我们管理k8s的时候，会把`/etc/kubernetes/admin.conf`拷贝到`$HOME/.kube/config` 中用来管理集群，在更新证书的过程中，会更新`admin.conf`的证书内容，所以在更新证书后，我们需要重新拷贝这个管理凭据到家目录

先查看原来自己家目录的config文件有效期

```bash
cat /root/.kube/config
```
输出如下：

```text
...
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURLVENDQWhHZ0F3SUJBZ0lJVitUa1ZuSFVmam93RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TkRBMU16RXdNRFUzTkRCYUZ3MHlOVEExTXpFd01UQXlOREZhTUR3eApIekFkQmdOVkJBb1RGbXQxWW1WaFpHMDZZMngxYzNSbGNpMWhaRzFwYm5NeEdUQVhCZ05WQkFNVEVHdDFZbVZ5CmJtVjBaWE10WVdSdGFXNHdnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFDbEpsc1MKTlNKdTJVLzNHa29HenlmU1crYXBUQ2pWK1U1ZjR6ZEJ6MWIwbG42R0xhRTFrSXg4WjlPa1FOcWZiM0o2MjdXMgpWWXM2V0Jud29LMGlsREVOYW9JTEY4SXZEMzg0OWhrWjFJd29GNy9qdHFCVHdwWjdJRi93dkdhTGNHcnFBcHEvCkltaWF5MmIvdlV1UDUxcHZJOHNlMzlkVk5sRWhGNGdkS3c1MHZCa0pCVVBQdGt6VmR3L2pUT2QxamcyOE9tZkcKc3pOTWlWVmlmZ3dRRFNMZjhPWk9nMi9VeU56ZXlrZDMzVWdta2JXbnEwMHlVcFhyN0V1UWFFRyszUTVqM2FLMQozTDUxZ3VjTjlaU2tyN041dm9VQlNVZkU0UExRK0Y2OWF2OVRQNE1VYU5QbnVmWkxwYk81bXlWL29xZXNvNlJGCkhoNjZxNmpHZ05UMEhIckZBZ01CQUFHalZqQlVNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUsKQmdnckJnRUZCUWNEQWpBTUJnTlZIUk1CQWY4RUFqQUFNQjhHQTFVZEl3UVlNQmFBRkR1L3pPYUEwcnJ3WkhSdgpzbWRDWHJRd1MyVjhNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUFyUzZ4M3F2L0t0STdIUTBINlFmcUdocndzCk9KL2w5Vlo5Nml0ZHFXQi82VFFncWd6ZGZjdDVmeTE4bUwrRWpiUmozVWVvRllnb1hLdm16Y1lad3BGR292WGgKYVRPOGlzdVE2eFZub2ZNclpwUU1BM1BsZkJVdTZaY3lPUjU3RS9IdTZuNnp4TVFqMEN2N1BsaWNhZi9yU08yVgpVVGZRaUZGOEdMR3ZhcEtPTGNLb0J2VFpabHpKSjljdWxCRnNTak8zZHdUVDVxQWRTTUtLOUY2RDI4RnpzYWZDCnNvWHJBT2V1a1VPL3h2VFlwR09mNjlSa0VSMXk1cjZWM0NwL1RpTzViNVZuTnZ5dWJ0azNTRVVNMndoTWFpRTcKVjd4WFhHOHFSSEtQRTdranhxNERkZUlHV3J1M2w3cUZuMk5nbVloUndnREwrT2J2a1h1MU5YQ1ZnRVJCCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
...
```

把这个客户端证书用base64解密，得到证书文件

```bash
cat > config-old <<-'EOF'
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURLVENDQWhHZ0F3SUJBZ0lJVitUa1ZuSFVmam93RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TkRBMU16RXdNRFUzTkRCYUZ3MHlOVEExTXpFd01UQXlOREZhTUR3eApIekFkQmdOVkJBb1RGbXQxWW1WaFpHMDZZMngxYzNSbGNpMWhaRzFwYm5NeEdUQVhCZ05WQkFNVEVHdDFZbVZ5CmJtVjBaWE10WVdSdGFXNHdnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFDbEpsc1MKTlNKdTJVLzNHa29HenlmU1crYXBUQ2pWK1U1ZjR6ZEJ6MWIwbG42R0xhRTFrSXg4WjlPa1FOcWZiM0o2MjdXMgpWWXM2V0Jud29LMGlsREVOYW9JTEY4SXZEMzg0OWhrWjFJd29GNy9qdHFCVHdwWjdJRi93dkdhTGNHcnFBcHEvCkltaWF5MmIvdlV1UDUxcHZJOHNlMzlkVk5sRWhGNGdkS3c1MHZCa0pCVVBQdGt6VmR3L2pUT2QxamcyOE9tZkcKc3pOTWlWVmlmZ3dRRFNMZjhPWk9nMi9VeU56ZXlrZDMzVWdta2JXbnEwMHlVcFhyN0V1UWFFRyszUTVqM2FLMQozTDUxZ3VjTjlaU2tyN041dm9VQlNVZkU0UExRK0Y2OWF2OVRQNE1VYU5QbnVmWkxwYk81bXlWL29xZXNvNlJGCkhoNjZxNmpHZ05UMEhIckZBZ01CQUFHalZqQlVNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUsKQmdnckJnRUZCUWNEQWpBTUJnTlZIUk1CQWY4RUFqQUFNQjhHQTFVZEl3UVlNQmFBRkR1L3pPYUEwcnJ3WkhSdgpzbWRDWHJRd1MyVjhNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUFyUzZ4M3F2L0t0STdIUTBINlFmcUdocndzCk9KL2w5Vlo5Nml0ZHFXQi82VFFncWd6ZGZjdDVmeTE4bUwrRWpiUmozVWVvRllnb1hLdm16Y1lad3BGR292WGgKYVRPOGlzdVE2eFZub2ZNclpwUU1BM1BsZkJVdTZaY3lPUjU3RS9IdTZuNnp4TVFqMEN2N1BsaWNhZi9yU08yVgpVVGZRaUZGOEdMR3ZhcEtPTGNLb0J2VFpabHpKSjljdWxCRnNTak8zZHdUVDVxQWRTTUtLOUY2RDI4RnpzYWZDCnNvWHJBT2V1a1VPL3h2VFlwR09mNjlSa0VSMXk1cjZWM0NwL1RpTzViNVZuTnZ5dWJ0azNTRVVNMndoTWFpRTcKVjd4WFhHOHFSSEtQRTdranhxNERkZUlHV3J1M2w3cUZuMk5nbVloUndnREwrT2J2a1h1MU5YQ1ZnRVJCCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
EOF
```

上面的命令将客户端证书的base64信息写入到了config-old文件中，我们来对它进行还原

```bash
base64 --decode config-old
```
输出以下内容：

```text
-----BEGIN CERTIFICATE-----
MIIDKTCCAhGgAwIBAgIIV+TkVnHUfjowDQYJKoZIhvcNAQELBQAwFTETMBEGA1UE
AxMKa3ViZXJuZXRlczAeFw0yNDA1MzEwMDU3NDBaFw0yNTA1MzEwMTAyNDFaMDwx
HzAdBgNVBAoTFmt1YmVhZG06Y2x1c3Rlci1hZG1pbnMxGTAXBgNVBAMTEGt1YmVy
bmV0ZXMtYWRtaW4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQClJlsS
NSJu2U/3GkoGzyfSW+apTCjV+U5f4zdBz1b0ln6GLaE1kIx8Z9OkQNqfb3J627W2
VYs6WBnwoK0ilDENaoILF8IvD3849hkZ1IwoF7/jtqBTwpZ7IF/wvGaLcGrqApq/
Imiay2b/vUuP51pvI8se39dVNlEhF4gdKw50vBkJBUPPtkzVdw/jTOd1jg28OmfG
szNMiVVifgwQDSLf8OZOg2/UyNzeykd33UgmkbWnq00yUpXr7EuQaEG+3Q5j3aK1
3L51gucN9ZSkr7N5voUBSUfE4PLQ+F69av9TP4MUaNPnufZLpbO5myV/oqeso6RF
Hh66q6jGgNT0HHrFAgMBAAGjVjBUMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUEDDAK
BggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFDu/zOaA0rrwZHRv
smdCXrQwS2V8MA0GCSqGSIb3DQEBCwUAA4IBAQArS6x3qv/KtI7HQ0H6QfqGhrws
OJ/l9VZ96itdqWB/6TQgqgzdfct5fy18mL+EjbRj3UeoFYgoXKvmzcYZwpFGovXh
aTO8isuQ6xVnofMrZpQMA3PlfBUu6ZcyOR57E/Hu6n6zxMQj0Cv7Plicaf/rSO2V
UTfQiFF8GLGvapKOLcKoBvTZZlzJJ9culBFsSjO3dwTT5qAdSMKK9F6D28FzsafC
soXrAOeukUO/xvTYpGOf69RkER1y5r6V3Cp/TiO5b5VnNvyubtk3SEUM2whMaiE7
V7xXXG8qRHKPE7kjxq4DdeIGWru3l7qFn2NgmYhRwgDL+ObvkXu1NXCVgERB
-----END CERTIFICATE-----
```

看看证书有效期

```bash
base64 --decode config-old | openssl x509 -in - -text
```
从输出看，2025年5月31日过期，也就是说证书更新的过程并没有更新config文件，所以我们才要手工更新

```text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 6333438035917831738 (0x57e4e45671d47e3a)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: May 31 00:57:40 2024 GMT
            Not After : May 31 01:02:41 2025 GMT
...
```

**更新config文件**

```bash
rm -rf /root/.kube/config
cp /etc/kubernetes/admin.conf /root/.kube/config
```

更新后重新用上面的步骤查看有效期，发现有效期已经成功更新

```text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 7080250541025461858 (0x62421a5ab2970662)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = kubernetes
        Validity
            Not Before: May 31 00:57:40 2024 GMT
            Not After : Aug  2 03:45:19 2025 GMT
```

## 重启集群应用新证书

由于集群本身是以静态pod方式存在的，所以重启的方法就是移除静态pod，并在等待期之后，重新移入

将清单文件从 /etc/kubernetes/manifests/ 移除

```bash
mv /etc/kubernetes/manifests/ /tmp/
```

等待 Pod 消失，大约 20 秒，这里建议多等等

将清单文件放回原位

```bash
mv /tmp/manifests /etc/kubernetes/
```

## 确认集群恢复正常

```bash
kubectl get pod -n kube-system
```
正常输出pod列表
```text
NAME                                       READY   STATUS    RESTARTS      AGE
calico-kube-controllers-5b9b456c66-mf6r4   1/1     Running   2 (53s ago)   63d
calico-node-g8th2                          1/1     Running   1 (74m ago)   63d
calico-node-gd44x                          1/1     Running   1 (63d ago)   63d
calico-node-qh98w                          1/1     Running   1 (74m ago)   63d
coredns-7c445c467-k6njz                    1/1     Running   1 (74m ago)   63d
coredns-7c445c467-prx7f                    1/1     Running   1 (63d ago)   63d
etcd-k8s-master                            1/1     Running   0             63d
kube-apiserver-k8s-master                  1/1     Running   0             63d
kube-controller-manager-k8s-master         1/1     Running   0             63d
kube-proxy-t69vm                           1/1     Running   1 (74m ago)   63d
kube-proxy-zwfmq                           1/1     Running   1 (74m ago)   63d
kube-proxy-zxxgg                           1/1     Running   1 (63d ago)   63d
kube-scheduler-k8s-master                  1/1     Running   0             63d

```

已完成整个证书更新过程


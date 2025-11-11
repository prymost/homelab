Here i test various k8s manifests and helm variables. As my test cluster inside devcontainer is ephemeral and is not connected to fluxcd, i need to manually apply the manifests here. Once i am happy with the results, i can copy the changes to the clusters folder.

# Helm

## Installing a chart with custom values

```bash
helm install <name> <source> --create-namespace --namespace <namespace> --version <version> -f <values-file>
```

## Upgrading a chart with custom values

```bash
helm upgrade <name> <source> --namespace <namespace> --version <version> -f <values-file>
```

## Uninstalling a chart

```bash
helm uninstall <name> --namespace <namespace>
```
## Example

And here are all the commands for specific charts i use. I leave them here bacause i'm lazy and just want to copy paste them when testing a small change in the devcontainer.

### NFS Provisioner (for Dev Environment)

To set up the NFS provisioner in the devcontainer, use the following Helm command. This uses the common values and overrides them with the dev-specific path.

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --create-namespace --namespace nfs-provisioner --version 4.0.18 -f sandbox/nfs-provisioner/values.yaml -f sandbox/nfs-provisioner/values-dev.yaml

helm upgrade nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace nfs-provisioner -f sandbox/nfs-provisioner/values.yaml -f sandbox/nfs-provisioner/values-dev.yaml

helm uninstall nfs-subdir-external-provisioner -n nfs-provisioner
```

### Mealie

The Mealie application is managed with raw Kubernetes manifests.

```bash
# Apply all manifests, including network policies
kubectl apply -k sandbox/mealie/

# Delete all manifests
kubectl delete -k sandbox/mealie/
```

### Monitoring stack (Prometheus, Grafana)

```bash
helm install monitoring oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack --create-namespace --namespace monitoring --version 78.0.0 -f sandbox/monitoring/prometheus-values.yaml -f sandbox/monitoring/grafana-values.yaml -f sandbox/monitoring/alertmanager-values.yaml -f sandbox/monitoring/dashboards.yaml -f sandbox/monitoring/alert-rules.yaml
helm upgrade monitoring oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack --namespace monitoring -f sandbox/monitoring/prometheus-values.yaml -f sandbox/monitoring/grafana-values.yaml -f sandbox/monitoring/alertmanager-values.yaml -f sandbox/monitoring/dashboards.yaml -f sandbox/monitoring/alert-rules.yaml
helm uninstall monitoring -n monitoring
```


### In-cluster Security Scans (Trivy Operator)

```bash
helm install trivy-operator oci://ghcr.io/aquasecurity/helm-charts/trivy-operator --create-namespace --namespace trivy --version 0.31.0 -f sandbox/trivy/values.yaml
helm upgrade trivy-operator oci://ghcr.io/aquasecurity/helm-charts/trivy-operator --namespace trivy -f sandbox/trivy/values.yaml
helm uninstall trivy-operator -n trivy

# Apply network policies for Trivy Operator
kubectl apply -k sandbox/trivy/network-policies/
```

### Minecraft Server

```bash
helm repo add itzg https://itzg.github.io/minecraft-server-charts/

helm install minecraft itzg/minecraft --create-namespace --namespace minecraft --version 5.0.0 -f sandbox/minecraft/values.yaml
helm upgrade minecraft itzg/minecraft --namespace minecraft -f sandbox/minecraft/values.yaml
helm uninstall minecraft -n minecraft

# Apply network policies
kubectl apply -k sandbox/minecraft/network-policies/
```

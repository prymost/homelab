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

### Monitoring stack (Prometheus, Grafana)

```bash
helm install monitoring oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack --create-namespace --namespace monitoring --version 78.0.0 -f sandbox/monitoring/values.yaml -f sandbox/monitoring/dashboards.yaml
helm upgrade monitoring oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack --namespace monitoring -f sandbox/monitoring/values.yaml -f sandbox/monitoring/dashboards.yaml
helm uninstall monitoring -n monitoring
```


### In-cluster Security Scans (Trivy Operator)

```bash
helm install trivy-operator oci://ghcr.io/aquasecurity/helm-charts/trivy-operator --create-namespace --namespace trivy --version 0.31.0 -f sandbox/trivy/values.yaml
helm upgrade trivy-operator oci://ghcr.io/aquasecurity/helm-charts/trivy-operator --namespace trivy -f sandbox/trivy/values.yaml
helm uninstall trivy-operator -n trivy
```

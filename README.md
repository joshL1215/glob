# glob

`glob` is a homelab project that turns a GPU-equipped laptop into a small virtualized Kubernetes platform for learning, observability, and local AI workloads.

The setup uses:
- **libvirt + Terraform** to create and network VMs
- **Ansible** to bootstrap hosts and install k3s
- **Argo CD (app-of-apps)** to continuously deploy platform services
- **NVIDIA device integration** so GPU workloads can run in-cluster

## Project goals

- Build a repeatable local platform for Kubernetes practice
- Keep infrastructure declarative and GitOps-managed
- Expose GPU capacity to cluster workloads (for CUDA/inference experiments)
- Run a full observability stack to understand cluster behavior

## High-level architecture

- Host machine (`glob`, `10.77.0.1`) runs libvirt and also joins k3s as a **GPU node**
- VM nodes (created by Terraform):
  - `lab-cp-1` (`10.77.0.11`) — k3s control plane
  - `lab-w1` (`10.77.0.21`) — worker
  - `lab-w2` (`10.77.0.22`) — worker
- Ansible configures base OS, firewalling, k3s, kubeconfig, bootstrap secrets, and Argo CD
- Argo CD syncs manifests from this repo under `k8s/apps`

## Repository layout

```text
terraform/
  00-bootstrap/   # lab network, base image, nwfilter
  10-vms/         # node definitions, cloud-init, VM domains

ansible/
  inventory.yml
  group_vars/all.yml
  playbooks/
    base.yml      # baseline packages + UFW
    k3s.yml       # control plane + worker install
    k3s-gpu.yml   # join host as GPU node
    kubeconfig.yml
    secrets.yml   # bootstrap secrets used by apps
    argocd.yml    # install Argo CD + apply root app

k8s/
  root.yaml       # app-of-apps root Application
  apps/           # Argo CD Applications
  values/         # Helm values consumed by Applications
  dashboards/     # Grafana dashboards
  gpu/            # GPU smoke test manifest
  vllm/           # vLLM deployment, service, PVC, ServiceMonitor
```

## GitOps applications managed by Argo CD

- `argo-cd`
- `prometheus-operator-crds`
- `kube-prometheus-stack`
- `loki`
- `alloy`
- `nvidia-device-plugin`
- `dcgm-exporter`
- `dashboards`
- `vllm`

## Typical bootstrap flow

1. Apply Terraform bootstrap:
   - `terraform/00-bootstrap` creates network, base image, and nwfilter
2. Apply Terraform VM layer:
   - `terraform/10-vms` creates `lab-cp-1`, `lab-w1`, `lab-w2`
3. Run Ansible playbooks:
   - base host config
   - k3s control plane and workers
   - GPU host join
   - kubeconfig and bootstrap secrets
   - Argo CD install and root app apply
4. Argo CD continuously reconciles platform apps from this repository

## Useful operations

```bash
# Grafana UI
kubectl port-forward svc/kube-prometheus-stack-grafana -n observability 3000:80

# Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Quick GPU validation
kubectl apply -f k8s/gpu/smoke-test.yaml
kubectl logs pod/gpu-smoke-test
```

## Notes

- k3s version is pinned in `ansible/group_vars/all.yml`
- The `vllm` workload is scheduled to GPU-capable nodes and uses a PVC to persist model cache
- This project is intentionally optimized for learning and iterative homelab experimentation

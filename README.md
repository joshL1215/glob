My old laptop turned into VM cluster hypervisor hosting some apps for learning purposes

The laptop has a GPU that I want to be accessible through some self-hosted applications so I can do CUDA/gpu stuff on my macbook but overall this is for learning purposes

### useful
- kubectl port-forward svc/kube-prometheus-stack-grafana -n observability 3000:80

- kubectl port-forward svc/argocd-server -n argocd 8080:80

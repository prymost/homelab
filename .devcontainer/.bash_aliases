alias k=kubectl
alias kgp='kubectl get pods'
alias kgpo='kubectl get pods -o wide'
alias kgs='kubectl get svc'

source <(kubectl completion bash)
complete -o default -F __start_kubectl k

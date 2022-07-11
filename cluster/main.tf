resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "4.9.12"
  namespace        = "argocd"
  create_namespace = true
  cleanup_on_fail  = true

  values = [
    "${file("./argo/values.yaml")}"
  ]

}
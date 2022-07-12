resource "helm_release" "cilium" {
  chart           = "cilium"
  name            = "cilium"
  repository      = "https://helm.cilium.io/"
  version         = "1.11.6"
  namespace       = "kube-system"
  cleanup_on_fail = true

  set {
    name  = "tunnel"
    value = "disabled"
  }

  set {
    name = "ipv4NativeRoutingCIDR"
    value = "10.16.0.0/14"
  }
}

resource "helm_release" "argocd" {
  depends_on       = [helm_release.cilium]
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "4.9.12"
  namespace        = "argocd"
  create_namespace = true
  cleanup_on_fail  = true
}

locals {
  ssh_repo_url = "git@github.com:spacemule/k3s-hetz.git"
}

resource "kubernetes_secret" manifest_repo_creds {
  depends_on = [helm_release.argocd]
  metadata {
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
    name      = "argoproj-ssh-creds"
    namespace = "argocd"
  }
  binary_data = {
    "url"           = base64encode(local.ssh_repo_url)
    "sshPrivateKey" = var.manifest_repo_private_key
  }
}

resource "kubernetes_manifest" "sealed_secrets_key_secret" {
  manifest = {
    "apiVersion" = "v1"
    "data"       = {
      "tls.crt" = var.sealed_secrets_tls_crt
      "tls.key" = var.sealed_secrets_tls_key
    }
    "kind"     = "Secret"
    "metadata" = {
      "labels" = {
        "sealedsecrets.bitnami.com/sealed-secrets-key" = "active"
      }
      "name"      = "sealed-secrets-key"
      "namespace" = "kube-system"
    }
  }
}

resource "kubernetes_manifest" "app_of_apps" {
  depends_on = [
    helm_release.argocd,
    kubernetes_secret.manifest_repo_creds,
    kubernetes_manifest.sealed_secrets_key_secret,
  ]
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata"   = {
      "finalizers" = [
        "resources-finalizer.argocd.argoproj.io",
      ]
      "name"      = var.argocd_app_of_apps_name
      "namespace" = "argocd"
    }
    "spec" = {
      "destination" = {
        "namespace" = "default"
        "server"    = "https://kubernetes.default.svc"
      }
      "project" = "default"
      "source"  = {
        "helm" = {
          "valueFiles" = [
            var.argocd_app_of_apps_values_file,
          ]
        }
        "path"           = var.argocd_app_of_apps_path
        "repoURL"        = local.ssh_repo_url
        "targetRevision" = var.argocd_app_of_apps_target_revision
      }
      "syncPolicy" = {
        "automated" = {
          "prune" = var.argocd_app_of_apps_prune
        }
        "syncOptions" = [
          "CreateNamespace=true",
        ]
      }
    }
  }
}
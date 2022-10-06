module "k3s" {
  source           = "../infra/"
  control_planes   = ["cpx11"]
  network_cidr     = "10.0.0.0/12"
  services_cidr    = "10.15.1.0/24"
  subnet_cidr      = "10.0.0.0/16"
  workers          = ["cpx11"]
  hcloud_token     = var.hcloud_token
  ssh_pubkey       = var.ssh_pubkey
  setup_complete   = true
  postgres_enabled = true
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "4.10.5"
  namespace        = "argocd"
  create_namespace = true
  cleanup_on_fail  = true

  set {
    name  = "externalRedis.host"
    value = module.k3s.db_ip
  }

  set {
    name  = "redis.enabled"
    value = "false"
  }

  set {
    name  = "controller.replicas"
    value = 2
  }

  set {
    name  = "server.replicas"
    value = 2
  }

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

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

resource "kubernetes_manifest" "app_of_apps" {
  depends_on = [
    helm_release.argocd,
    kubernetes_secret.manifest_repo_creds,
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
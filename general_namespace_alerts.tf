resource "kubernetes_manifest" "prometheusrule_general_namespace_alerts" {
  count = var.enable_prometheusrules ? 1 : 0
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "PrometheusRule"
    "metadata" = {
      "labels"    = var.prometheusrules_labels
      "name"      = var.namespace_rules_name
      "namespace" = var.helm_namespace
    }
    "spec" = {
      "groups" = [
        {
          "name" = "containers.rules"
          "rules" = [
            {
              "alert" = "ManyContainerRestarts"
              "annotations" = {
                "message" = "Container {{ $labels.namespace }}/{{ $labels.pod }}/{{ $labels.container }} restarted {{ $value }} times in the last 8 hours."
              }
              "expr" = "sum by(container, pod, namespace) (kube_pod_container_status_restarts_total - kube_pod_container_status_restarts_total offset 8h > 10)"
              "for"  = "2m"
              "labels" = {
                "scope"    = "namespace"
                "severity" = "minor"
              }
            },
            {
              "alert" = "ContainerWaiting"
              "annotations" = {
                "message" = "Container {{ $labels.namespace }}/{{ $labels.pod }}/{{ $labels.container }} has been in {{ $labels.reason }} for over an hour."
              }
              "expr" = "sum by (container, pod, namespace, reason) (avg_over_time(kube_pod_container_status_waiting_reason{reason!=\"CrashLoopBackOff\"}[15m:])) > 0.8"
              "for"  = "1h"
              "labels" = {
                "scope"    = "namespace"
                "severity" = "minor"
              }
            },
          ]
        },
        {
          "name" = "pods.rules"
          "rules" = [
            {
              "alert" = "PodNotReady"
              "annotations" = {
                "message" = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready state for longer than 15 minutes."
              }
              "expr" = "sum by(namespace, pod) (max by(namespace, pod) (kube_pod_status_phase{job=\"kube-state-metrics\",namespace=~\".*\",phase=~\"Pending|Unknown\"}) * on(namespace, pod) group_left(owner_kind) topk by(namespace, pod) (1, max by(namespace, pod, owner_kind) (kube_pod_owner{owner_kind!=\"Job\"}))) > 0"
              "for"  = "15m"
              "labels" = {
                "scope"    = "namespace"
                "severity" = "minor"
              }
            },
          ]
        },
        {
          "name" = "jobs.rules"
          "rules" = [
            {
              "alert" = "JobFailed"
              "annotations" = {
                "message" = "Job {{ $labels.namespace }}/{{ $labels.job_name }} failed to complete. Removing the failed job after investigation should clear this alert."
              }
              "expr" = "sum by(namespace, job_name) (kube_job_failed > 0)"
              "for"  = "15m"
              "labels" = {
                "scope"    = "namespace"
                "severity" = "minor"
              }
            },
            {
              "alert" = "JobIncomplete"
              "annotations" = {
                "message" = "Job {{ $labels.namespace }}/{{ $labels.job_name }} is taking more than 12 hours to complete."
              }
              "expr" = "(sum by (namespace, job_name) (kube_job_spec_completions) unless sum by (namespace, job_name) (kube_job_complete == 1)) unless sum by (namespace, job_name) (kube_job_failed == 1)"
              "for"  = "12h"
              "labels" = {
                "scope"    = "namespace"
                "severity" = "minor"
              }
            },
            {
              "alert" = "CompletedJobsNotCleared"
              "annotations" = {
                "message" = "Namespace {{ $labels.namespace }} has {{ $value }} completed jobs older than 24h."
              }
              "expr" = "count by (namespace) (kube_job_status_completion_time < (time() - 86400)) > 20"
              "for"  = "15m"
              "labels" = {
                "scope"    = "namespace"
                "severity" = "minor"
              }
            },
          ]
        },
      ]
    }
  }
}

#!/bin/bash

##############################################################################

# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_suse_ai.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
fi
else
  CLUSTER_NAME=aicluster01
  OTEL_NAMESPACE=opentelemetry
  OTEL_HELM_REPO_URL=https://open-telemetry.github.io/opentelemetry-helm-charts
  OTEL_VERSION=
fi

#LICENSES_FILE=authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=otel_custom_overrides.yaml

##############################################################################
#   Functions
##############################################################################

check_for_kubectl() {
  if ! echo $* | grep -q force
  then
   if ! which kubectl > /dev/null
   then
     echo
     echo "ERROR: This must be run on a machine with the kubectl command installed."
     echo "       Run this script on a control plane node or management machine."
     echo
     echo "       Exiting."
     echo
     exit
   fi
  fi
}

check_for_helm() {
  if ! echo $* | grep -q force
  then
   if ! which helm > /dev/null
   then
     echo
     echo "ERROR: This must be run on a machine with the helm command installed."
     echo "       Run this script on a control plane node or management machine."
     echo
     echo "       Exiting."
     echo
     exit
   fi
  fi
}

##############################################################################

create_otel_secret() {
  if ! [ -z ${OTEL_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${OTEL_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${OTEL_NAMESPACE}"
      kubectl create namespace ${OTEL_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${OTEL_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q open-telemetry-collector
    then
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=API_KEY=${OBSERVABILITY_API_KEY}"
      kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=API_KEY=${OBSERVABILITY_API_KEY}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} get secrets"
      kubectl -n ${OTEL_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector"
      kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} delete secret open-telemetry-collector"
      kubectl -n ${OTEL_NAMESPACE} delete secret open-telemetry-collector
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=API_KEY=${OBSERVABILITY_API_KEY}"
      kubectl -n ${OTEL_NAMESPACE} create secret generic open-telemetry-collector --from-literal=${OBSERVABILITY_API_KEY}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} get secrets"
      kubectl -n ${OTEL_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector"
      kubectl -n ${OTEL_NAMESPACE} describe secret open-telemetry-collector
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  fi
}

create_otel_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "
extraEnvsFrom:
  - secretRef:
      name: open-telemetry-collector
mode: deployment
image:
  repository: \"otel/opentelemetry-collector-k8s\"
  tag: \"0.123.0\"
ports:
  metrics:
    enabled: true
presets:
  kubernetesAttributes:
    enabled: true
    extractAllPodLabels: true
config:
  receivers:
    prometheus:
      config:
        scrape_configs:
        - job_name: 'gpu-metrics'
          scrape_interval: 10s
          scheme: http
          kubernetes_sd_configs:
            - role: endpoints
              namespaces:
                names:
                - gpu-operator
  exporters:
    otlp:
      endpoint: http://suse-observability-otel-collector.${OTEL_NAMESPACE}.svc.cluster.local:4317 
      headers:
        Authorization: \"SUSEObservability \${env:API_KEY}\"
      tls:
        insecure: true
  processors:
    tail_sampling:
      decision_wait: 10s
      policies:
      - name: rate-limited-composite
        type: composite
        composite:
          max_total_spans_per_second: 500
          policy_order: [errors, slow-traces, rest]
          composite_sub_policy:
          - name: errors
            type: status_code
            status_code:
              status_codes: [ ERROR ]
          - name: slow-traces
            type: latency
            latency:
              threshold_ms: 1000
          - name: rest
            type: always_sample
          rate_allocation:
          - policy: errors
            percent: 33
          - policy: slow-traces
            percent: 33
          - policy: rest
            percent: 34
    resource:
      attributes:
      - key: k8s.cluster.name
        action: upsert
        value: ${CLUSTER_NAME} 
      - key: service.instance.id
        from_attribute: k8s.pod.uid
        action: insert
    filter/dropMissingK8sAttributes:
      error_mode: ignore
      traces:
        span:
          - resource.attributes[\"k8s.node.name\"] == nil
          - resource.attributes[\"k8s.pod.uid\"] == nil
          - resource.attributes[\"k8s.namespace.name\"] == nil
          - resource.attributes[\"k8s.pod.name\"] == nil
  connectors:
    spanmetrics:
      metrics_expiration: 5m
      namespace: otel_span
    routing/traces:
      error_mode: ignore
      table:
      - statement: route()
        pipelines: [traces/sampling, traces/spanmetrics]
  service:
    extensions:
      - health_check
    pipelines:
      traces:
        receivers: [otlp, jaeger]
        processors: [filter/dropMissingK8sAttributes, memory_limiter, resource]
        exporters: [routing/traces]
      traces/spanmetrics:
        receivers: [routing/traces]
        processors: []
        exporters: [spanmetrics]
      traces/sampling:
        receivers: [routing/traces]
        processors: [tail_sampling, batch]
        exporters: [debug, otlp]
      metrics:
        receivers: [otlp, spanmetrics, prometheus]
        processors: [memory_limiter, resource, batch]
        exporters: [debug, otlp]
 " > ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

create_otel_rbac_manifest() {
  echo "Writing out otel-rbac.yaml file ..."
  echo
  echo "
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: suse-observability-otel-scraper
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
    verbs:
      - list
      - watch

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: suse-observability-otel-scraper
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: suse-observability-otel-scraper
subjects:
  - kind: ServiceAccount
    name: opentelemetry-collector
    namespace: observability
  " > otel-rbac.yaml
  echo
  cat otel-rbac.yaml
}

install_opentelemetry_collector() {
  if ! [ -z ${OTEL_VERSION} ]
  then
    local OTEL_VER_ARG="--version ${OTEL_VERSION}"
  fi

  echo "Installing the OpenTelemetry Collector ..."
  echo "------------------------------------------------------------"

  echo "COMMAND: helm repo add open-telemetry ${OTEL_HELM_REPO_URL}"
  helm repo add open-telemetry ${OTEL_HELM_REPO_URL}

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm upgrade --install opentelemetry-collector --namespace ${OTEL_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} open-telemetry/opentelemetry-collector ${OTEL_VER_ARG}"
  helm upgrade --install opentelemetry-collector --namespace ${OTEL_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} open-telemetry/opentelemetry-collector ${OTEL_VER_ARG}
  echo

  echo
  echo "COMMAND: kubectl -n ${OTEL_NAMESPACE} rollout status deploy/opentelemetry-collector"
  kubectl -n ${OTEL_NAMESPACE} rollout status deploy/opentelemetry-collector
}

configure_otel_rbac() {
  echo "Configuring OpenTelemetry RBAC ..."
  echo
  echo "COMMAND: kubectl apply -n gpu-operator -f otel-rbac.yam"l
  kubectl apply -n gpu-operator -f otel-rbac.yaml
  echo
}


usage() {
  echo 
  echo "USAGE: ${0} [custom_overrides_only|install_only]"
  echo 
  echo "Options: "
  echo "    custom_overrides_only  (only write out the ${CUSTOM_OVERRIDES_FILE} file)"
  echo "    install_only           (only run an install using an existing ${CUSTOM_OVERRIDES_FILE} file)"
  echo
  echo "If no option is supplied the ${CUSTOM_OVERRIDES_FILE} file is created and"
  echo "is used to perform an installation using 'helm upgrade --install'."
  echo
  echo "Example: ${0}"
  echo "         ${0} custom_overrides_only"
  echo "         ${0} install_only"
  echo 
}

##############################################################################

case ${1} in
  custom_overrides_only)
    check_for_kubectl
    check_for_helm
    create_otel_custom_overrides_file
    display_custom_overrides_file
    create_otel_rbac_manifest
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    create_otel_secret
    install_opentelemetry_collector
    configure_otel_rbac
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    create_otel_secret
    create_otel_custom_overrides_file
    display_custom_overrides_file
    install_opentelemetry_collector
    create_otel_rbac_manifest
    configure_otel_rbac
  ;;
esac


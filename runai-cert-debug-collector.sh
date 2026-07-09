#!/bin/bash

# Run:AI Certification Kit - Debug Information Collector
# This script collects diagnostic information about the certification test failures
# Usage: ./runai-cert-debug-collector.sh

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Run:AI Certification Kit - Debug Information Collector      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# IMPORTANT: Verify kubectl context
# ============================================================================
echo "🔍 Verifying kubectl configuration..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ ERROR: kubectl is not installed or not in PATH"
    echo ""
    echo "Please install kubectl and try again."
    exit 1
fi

# Show current context
CURRENT_CONTEXT=$(kubectl config current-context 2>&1)
if [ $? -ne 0 ]; then
    echo "❌ ERROR: No kubectl context is set"
    echo ""
    echo "Please ensure your kubeconfig is properly configured:"
    echo "  export KUBECONFIG=/path/to/your/kubeconfig"
    echo "  kubectl config use-context <your-context>"
    exit 1
fi

echo "Current kubectl context: ${CURRENT_CONTEXT}"
echo ""

# Test cluster connectivity
echo "Testing cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ ERROR: Cannot connect to Kubernetes cluster"
    echo ""
    echo "Current context: ${CURRENT_CONTEXT}"
    echo ""
    echo "Please ensure:"
    echo "  1. Your kubeconfig context points to the cluster with Run:AI installed"
    echo "  2. You have network connectivity to the cluster"
    echo "  3. Your credentials are valid"
    echo ""
    echo "To change context:"
    echo "  kubectl config get-contexts"
    echo "  kubectl config use-context <your-runai-cluster-context>"
    exit 1
fi

echo "✅ Successfully connected to cluster"
echo ""

# Verify Run:AI is installed
echo "Verifying Run:AI installation..."
if ! kubectl get namespace runai &> /dev/null; then
    echo "⚠️  WARNING: Run:AI namespace 'runai' not found"
    echo ""
    echo "This script should be run against a cluster where Run:AI is installed."
    echo "Current context: ${CURRENT_CONTEXT}"
    echo ""
    echo "Do you want to continue anyway? (y/n)"
    read -r continue_anyway
    if [ "$continue_anyway" != "y" ] && [ "$continue_anyway" != "Y" ]; then
        echo "Exiting..."
        exit 1
    fi
else
    echo "✅ Run:AI namespace found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="runai-debug-${TIMESTAMP}"
mkdir -p "${OUTPUT_DIR}"

echo "📁 Creating debug package in: ${OUTPUT_DIR}"
echo ""

# Change to output directory
cd "${OUTPUT_DIR}"

# ============================================================================
# Section 1: Control Plane CLI Endpoint Testing
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Section 1: Testing Control Plane CLI Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Read control plane URL from user or environment
if [ -z "$CONTROL_PLANE_URL" ]; then
    echo "Please enter your Control Plane URL (e.g., https://runai-cp.example.com):"
    read -r CONTROL_PLANE_URL
fi

echo "Control Plane URL: $CONTROL_PLANE_URL"
echo ""

mkdir -p 01-control-plane-cli-test

echo "Testing CLI endpoint availability..." | tee 01-control-plane-cli-test/summary.txt

# Test 1: Check if CLI endpoint responds
echo "" | tee -a 01-control-plane-cli-test/summary.txt
echo "Test 1: HTTP HEAD request to CLI endpoint" | tee -a 01-control-plane-cli-test/summary.txt
echo "Command: curl -I ${CONTROL_PLANE_URL}/cli/linux" | tee -a 01-control-plane-cli-test/summary.txt
echo "----------------------------------------" | tee -a 01-control-plane-cli-test/summary.txt
curl -I "${CONTROL_PLANE_URL}/cli/linux" 2>&1 | tee 01-control-plane-cli-test/cli-endpoint-head.txt || echo "❌ Failed to reach CLI endpoint"
echo "" | tee -a 01-control-plane-cli-test/summary.txt

# Test 2: Download and inspect what's actually returned
echo "Test 2: Downloading CLI binary to inspect" | tee -a 01-control-plane-cli-test/summary.txt
echo "Command: curl -o cli-download-test ${CONTROL_PLANE_URL}/cli/linux" | tee -a 01-control-plane-cli-test/summary.txt
echo "----------------------------------------" | tee -a 01-control-plane-cli-test/summary.txt
if curl -o 01-control-plane-cli-test/cli-download-test "${CONTROL_PLANE_URL}/cli/linux" 2>&1 | tee 01-control-plane-cli-test/cli-download-output.txt; then
    echo "✅ Download completed" | tee -a 01-control-plane-cli-test/summary.txt
    
    # Check file type
    echo "" | tee -a 01-control-plane-cli-test/summary.txt
    echo "File type:" | tee -a 01-control-plane-cli-test/summary.txt
    file 01-control-plane-cli-test/cli-download-test | tee -a 01-control-plane-cli-test/summary.txt
    
    # Show file size
    echo "File size:" | tee -a 01-control-plane-cli-test/summary.txt
    ls -lh 01-control-plane-cli-test/cli-download-test | tee -a 01-control-plane-cli-test/summary.txt
    
    # Show first 50 lines to see if it's HTML/text
    echo "" | tee -a 01-control-plane-cli-test/summary.txt
    echo "First 50 lines of downloaded file:" | tee -a 01-control-plane-cli-test/summary.txt
    head -50 01-control-plane-cli-test/cli-download-test > 01-control-plane-cli-test/cli-file-head.txt 2>&1 || true
    cat 01-control-plane-cli-test/cli-file-head.txt | tee -a 01-control-plane-cli-test/summary.txt
    
    # Check if it's an ELF binary
    if file 01-control-plane-cli-test/cli-download-test | grep -q "ELF"; then
        echo "✅ File appears to be a valid ELF binary" | tee -a 01-control-plane-cli-test/summary.txt
    elif file 01-control-plane-cli-test/cli-download-test | grep -q "HTML"; then
        echo "❌ ERROR: File is HTML, not a binary!" | tee -a 01-control-plane-cli-test/summary.txt
    else
        echo "⚠️  WARNING: File is not an ELF binary!" | tee -a 01-control-plane-cli-test/summary.txt
    fi
else
    echo "❌ Failed to download CLI" | tee -a 01-control-plane-cli-test/summary.txt
fi
echo ""

# Test 3: Test with authentication (if needed)
echo "Test 3: Testing CLI endpoint with potential authentication" | tee -a 01-control-plane-cli-test/summary.txt
echo "Note: If authentication is required, this may explain the issue" | tee -a 01-control-plane-cli-test/summary.txt
curl -v "${CONTROL_PLANE_URL}/cli/linux" 2>&1 | head -100 > 01-control-plane-cli-test/cli-verbose-output.txt
cat 01-control-plane-cli-test/cli-verbose-output.txt | tee -a 01-control-plane-cli-test/summary.txt
echo ""

# ============================================================================
# Section 2: Pod Status - Container Toolkit and Core Components
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 Section 2: Run:AI Pod Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 02-pod-status

echo "Collecting pod status information..."

# Get all pods in runai namespace
echo "All Run:AI pods:" | tee 02-pod-status/summary.txt
kubectl get pods -n runai --no-headers 2>&1 | tee 02-pod-status/all-pods.txt || echo "❌ Failed to get pods"
echo "" | tee -a 02-pod-status/summary.txt

# Get pods in all runai namespaces
echo "All pods in runai-* namespaces:" | tee -a 02-pod-status/summary.txt
kubectl get pods -A | grep runai 2>&1 | tee 02-pod-status/all-runai-namespace-pods.txt || echo "❌ Failed to get pods"
echo "" | tee -a 02-pod-status/summary.txt

# Detailed info on container-toolkit pods
echo "Container Toolkit DaemonSet pods:" | tee -a 02-pod-status/summary.txt
kubectl get pods -n runai -l app=runai-container-toolkit -o wide 2>&1 | tee 02-pod-status/container-toolkit-pods.txt || echo "❌ Failed to get container-toolkit pods"
echo "" | tee -a 02-pod-status/summary.txt

# Describe container-toolkit pods (all instances)
echo "Describing all container-toolkit pods..." | tee -a 02-pod-status/summary.txt
kubectl get pods -n runai -l app=runai-container-toolkit -o name 2>/dev/null | while read pod; do
    pod_name=$(basename "$pod")
    echo "Describing pod: $pod_name" | tee -a 02-pod-status/summary.txt
    kubectl describe pod "$pod_name" -n runai > "02-pod-status/describe-${pod_name}.txt" 2>&1 || echo "Failed to describe $pod_name"
    
    # Get logs if available
    echo "Getting logs for: $pod_name"
    kubectl logs "$pod_name" -n runai --all-containers=true --tail=200 > "02-pod-status/logs-${pod_name}.txt" 2>&1 || echo "No logs available for $pod_name"
done
echo ""

# Check for any pods not in Running state
echo "Non-running pods in runai namespace:" | tee -a 02-pod-status/summary.txt
kubectl get pods -n runai --field-selector=status.phase!=Running 2>&1 | tee 02-pod-status/non-running-pods.txt || true
echo "" | tee -a 02-pod-status/summary.txt

# Get pod events
echo "Recent events in runai namespace:" | tee -a 02-pod-status/summary.txt
kubectl get events -n runai --sort-by='.lastTimestamp' | tail -50 2>&1 | tee 02-pod-status/recent-events.txt || true
echo ""

# ============================================================================
# Section 3: Operator Status and Conditions
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  Section 3: Run:AI Operator Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 03-operator-status

echo "Collecting operator status..."

# Get RunaiConfig CRD (cluster-scoped, but typically in runai namespace)
echo "RunaiConfig status:" | tee 03-operator-status/summary.txt
kubectl get runaiconfig -n runai -o yaml 2>&1 | tee 03-operator-status/runaiconfig.yaml || echo "❌ Failed to get RunaiConfig"
echo "" | tee -a 03-operator-status/summary.txt

# Get operator pod status (operator is in runai namespace, NOT runai-backend)
echo "Operator pod status:" | tee -a 03-operator-status/summary.txt
kubectl get pods -n runai -l app=runai-operator 2>&1 | tee 03-operator-status/operator-pod.txt || echo "❌ Failed to get operator pod"
echo "" | tee -a 03-operator-status/summary.txt

# Describe operator pod
echo "Describing operator pod..."
kubectl get pods -n runai -l app=runai-operator -o name 2>/dev/null | while read pod; do
    pod_name=$(basename "$pod")
    kubectl describe pod "$pod_name" -n runai > "03-operator-status/describe-${pod_name}.txt" 2>&1 || echo "Failed to describe $pod_name"
    kubectl logs "$pod_name" -n runai --tail=500 > "03-operator-status/logs-${pod_name}.txt" 2>&1 || echo "No logs available for $pod_name"
done
echo ""

# Get operator conditions
echo "Checking operator conditions..."
kubectl get runaiconfig -n runai -o jsonpath='{.items[0].status.conditions}' 2>&1 | jq '.' > 03-operator-status/operator-conditions.json 2>&1 || true

# ============================================================================
# Section 4: DaemonSets and Deployments
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Section 4: DaemonSets and Deployments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 04-workloads

echo "Collecting workload information..."

# DaemonSets
echo "DaemonSets in runai namespace:" | tee 04-workloads/summary.txt
kubectl get daemonsets -n runai -o wide 2>&1 | tee 04-workloads/daemonsets.txt || echo "❌ Failed to get daemonsets"
echo "" | tee -a 04-workloads/summary.txt

# Describe container-toolkit daemonset
echo "Container Toolkit DaemonSet details:"
kubectl describe daemonset runai-container-toolkit -n runai > 04-workloads/describe-container-toolkit-ds.txt 2>&1 || echo "Failed to describe daemonset"

# Deployments
echo "Deployments in runai-backend namespace:" | tee -a 04-workloads/summary.txt
kubectl get deployments -n runai-backend -o wide 2>&1 | tee 04-workloads/deployments.txt || echo "❌ Failed to get deployments"
echo ""

# ============================================================================
# Section 5: Cluster Information
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Section 5: Cluster Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 05-cluster-info

echo "Collecting cluster information..."

# Cluster info
echo "Cluster info:" | tee 05-cluster-info/summary.txt
kubectl cluster-info 2>&1 | tee 05-cluster-info/cluster-info.txt || echo "❌ Failed to get cluster info"
echo "" | tee -a 05-cluster-info/summary.txt

# Node status
echo "Node status:" | tee -a 05-cluster-info/summary.txt
kubectl get nodes -o wide 2>&1 | tee 05-cluster-info/nodes.txt || echo "❌ Failed to get nodes"
echo "" | tee -a 05-cluster-info/summary.txt

# Node details (with taints, labels)
kubectl get nodes -o yaml > 05-cluster-info/nodes-detailed.yaml 2>&1 || true

# Kubernetes version
echo "Kubernetes version:" | tee -a 05-cluster-info/summary.txt
kubectl version --short 2>&1 | tee 05-cluster-info/k8s-version.txt || true
echo ""

# Storage classes
echo "Storage classes:" | tee -a 05-cluster-info/summary.txt
kubectl get storageclass 2>&1 | tee 05-cluster-info/storageclasses.txt || echo "❌ Failed to get storage classes"
echo ""

# ============================================================================
# Section 6: Namespaces and Resources
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Section 6: Namespaces and Resources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 06-resources

echo "Collecting resource information..."

# All runai namespaces
echo "All runai-related namespaces:" | tee 06-resources/summary.txt
kubectl get namespaces | grep runai 2>&1 | tee 06-resources/runai-namespaces.txt || echo "❌ Failed to get namespaces"
echo ""

# Services in runai namespaces
echo "Services in runai namespace:"
kubectl get services -n runai 2>&1 | tee 06-resources/services-runai.txt || true

echo "Services in runai-backend namespace:"
kubectl get services -n runai-backend 2>&1 | tee 06-resources/services-runai-backend.txt || true

# ConfigMaps
echo "ConfigMaps in runai namespace:"
kubectl get configmaps -n runai 2>&1 | tee 06-resources/configmaps-runai.txt || true

# Secrets (names only, not content)
echo "Secrets in runai namespace (names only):"
kubectl get secrets -n runai 2>&1 | tee 06-resources/secrets-runai.txt || true

# ============================================================================
# Section 7: Ingress and Networking
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌍 Section 7: Ingress and Networking"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 07-networking

echo "Collecting networking information..."

# Ingresses
echo "Ingresses in runai-backend namespace:" | tee 07-networking/summary.txt
kubectl get ingress -n runai-backend -o wide 2>&1 | tee 07-networking/ingresses.txt || echo "❌ Failed to get ingresses"
kubectl get ingress -n runai-backend -o yaml > 07-networking/ingresses-detailed.yaml 2>&1 || true
echo ""

# Check if there's a traefik/nginx ingress controller
echo "Ingress controller pods:"
kubectl get pods -A | grep -E "ingress|traefik|nginx" 2>&1 | tee 07-networking/ingress-controllers.txt || true
echo ""

# ============================================================================
# Section 8: CRDs and Custom Resources
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Section 8: Custom Resource Definitions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 08-crds

echo "Collecting CRD information..."

# List all runai CRDs
echo "Run:AI CRDs:" | tee 08-crds/summary.txt
kubectl get crds | grep run.ai 2>&1 | tee 08-crds/runai-crds.txt || echo "❌ Failed to get CRDs"
echo ""

# Get runaiconfig details
kubectl get runaiconfig -A -o yaml > 08-crds/runaiconfig-all.yaml 2>&1 || true

# ============================================================================
# Section 9: Certification Test Results (if available)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Section 9: Certification Test Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p 09-test-results

# Ask if user wants to include certification test results
echo ""
echo "Do you have the certification test results directory to include? (y/n)"
read -r include_results

if [ "$include_results" = "y" ] || [ "$include_results" = "Y" ]; then
    echo "Please enter the path to the certification results directory:"
    echo "(e.g., /path/to/runai-certification-results-20251125-103936)"
    read -r results_path
    
    if [ -d "$results_path" ]; then
        echo "Copying certification test results..."
        cp -r "$results_path"/* 09-test-results/ 2>&1 || echo "Failed to copy some files"
        echo "✅ Test results included"
    else
        echo "⚠️  Directory not found, skipping test results"
    fi
else
    echo "Skipping test results inclusion"
fi

# ============================================================================
# Create Summary Report
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Creating Summary Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > 00-SUMMARY-REPORT.txt << 'SUMMARY_EOF'
╔════════════════════════════════════════════════════════════════╗
║   Run:AI Certification Kit - Debug Information Summary        ║
╚════════════════════════════════════════════════════════════════╝

This package contains comprehensive diagnostic information collected
to investigate Run:AI certification test failures.

CONTENTS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

01-control-plane-cli-test/
  • CLI endpoint HTTP responses
  • Downloaded CLI binary analysis
  • File type and content inspection
  • Summary of CLI download issues

02-pod-status/
  • All Run:AI pod statuses
  • Container-toolkit pod details
  • Pod descriptions and logs
  • Events related to pod failures

03-operator-status/
  • RunaiConfig CRD status
  • Operator pod logs and description
  • Operator conditions and state

04-workloads/
  • DaemonSet status (container-toolkit)
  • Deployment status
  • Workload descriptions

05-cluster-info/
  • Cluster information
  • Node status and details
  • Kubernetes version
  • Storage classes

06-resources/
  • Namespaces
  • Services
  • ConfigMaps
  • Secrets (names only)

07-networking/
  • Ingress configurations
  • Ingress controller status
  • Network routing setup

08-crds/
  • Run:AI Custom Resource Definitions
  • RunaiConfig resources

09-test-results/ (if included)
  • Certification test results
  • Allure reports
  • Test logs and attachments

KNOWN ISSUES DETECTED:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUMMARY_EOF

# Add detected issues to summary
echo "" >> 00-SUMMARY-REPORT.txt
echo "Issue Detection:" >> 00-SUMMARY-REPORT.txt
echo "" >> 00-SUMMARY-REPORT.txt

# Check CLI download
if [ -f "01-control-plane-cli-test/cli-download-test" ]; then
    if file 01-control-plane-cli-test/cli-download-test | grep -q "HTML"; then
        echo "❌ CRITICAL: CLI endpoint returns HTML instead of binary" >> 00-SUMMARY-REPORT.txt
        echo "   Location: 01-control-plane-cli-test/cli-download-test" >> 00-SUMMARY-REPORT.txt
        echo "" >> 00-SUMMARY-REPORT.txt
    elif ! file 01-control-plane-cli-test/cli-download-test | grep -q "ELF"; then
        echo "⚠️  WARNING: CLI download is not an ELF binary" >> 00-SUMMARY-REPORT.txt
        echo "   Location: 01-control-plane-cli-test/cli-download-test" >> 00-SUMMARY-REPORT.txt
        echo "" >> 00-SUMMARY-REPORT.txt
    else
        echo "✅ CLI binary appears valid" >> 00-SUMMARY-REPORT.txt
        echo "" >> 00-SUMMARY-REPORT.txt
    fi
fi

# Check container-toolkit pods
if [ -f "02-pod-status/container-toolkit-pods.txt" ]; then
    if grep -q "Pending\|Error\|CrashLoop" 02-pod-status/container-toolkit-pods.txt; then
        echo "❌ CRITICAL: Container-toolkit pods not running properly" >> 00-SUMMARY-REPORT.txt
        echo "   Location: 02-pod-status/container-toolkit-pods.txt" >> 00-SUMMARY-REPORT.txt
        echo "" >> 00-SUMMARY-REPORT.txt
    else
        echo "✅ Container-toolkit pods appear healthy" >> 00-SUMMARY-REPORT.txt
        echo "" >> 00-SUMMARY-REPORT.txt
    fi
fi

# Check operator status
if [ -f "03-operator-status/operator-conditions.json" ]; then
    if ! grep -q "Deployed" 03-operator-status/operator-conditions.json; then
        echo "⚠️  WARNING: Operator not in 'Deployed' state" >> 00-SUMMARY-REPORT.txt
        echo "   Location: 03-operator-status/operator-conditions.json" >> 00-SUMMARY-REPORT.txt
        echo "" >> 00-SUMMARY-REPORT.txt
    fi
fi

cat >> 00-SUMMARY-REPORT.txt << 'SUMMARY_EOF2'

NEXT STEPS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Review 00-SUMMARY-REPORT.txt for detected issues
2. Check 01-control-plane-cli-test/ for CLI endpoint problems
3. Check 02-pod-status/ for pod failures (especially container-toolkit)
4. Check 03-operator-status/ for operator deployment issues
5. Review logs in each section for detailed error messages

SENDING TO RUN:AI SUPPORT:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This entire directory will be packaged into a tar.gz file.
Send the resulting tar.gz file to Run:AI support for analysis.

Generated: $(date)
SUMMARY_EOF2

# ============================================================================
# Package Everything
# ============================================================================
cd ..

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Packaging Debug Information"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TARBALL="${OUTPUT_DIR}.tar.gz"

echo "Creating tarball: ${TARBALL}"
tar -czf "${TARBALL}" "${OUTPUT_DIR}"

echo ""
echo "✅ Debug package created successfully!"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    PACKAGE COMPLETE                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Package location: ${TARBALL}"
echo "📏 Package size: $(du -h "${TARBALL}" | cut -f1)"
echo ""
echo "📤 Next Steps:"
echo "   1. Review ${OUTPUT_DIR}/00-SUMMARY-REPORT.txt for issues"
echo "   2. Send ${TARBALL} to Run:AI support team"
echo "   3. Include this information in your support ticket"
echo ""
echo "🔍 To examine the package:"
echo "   tar -xzf ${TARBALL}"
echo "   cd ${OUTPUT_DIR}"
echo "   cat 00-SUMMARY-REPORT.txt"
echo ""


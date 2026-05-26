# =============================================================================
# Deployment Helper Scripts
# =============================================================================

#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${1:-production}"
ENVIRONMENT="${2:-staging}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Deploy application
deploy() {
    local image_tag="${1:-latest}"
    
    log_info "Deploying to $NAMESPACE with image tag: $image_tag"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/ -n "$NAMESPACE"
    
    # Set image
    kubectl set image deployment/app \
        app="$image_tag" \
        -n "$NAMESPACE"
    
    # Wait for rollout
    kubectl rollout status deployment/app -n "$NAMESPACE" --timeout=300s
    
    log_success "Deployment completed"
}

# Rollback to previous version
rollback() {
    log_info "Rolling back deployment in $NAMESPACE..."
    
    kubectl rollout undo deployment/app -n "$NAMESPACE"
    
    kubectl rollout status deployment/app -n "$NAMESPACE" --timeout=300s
    
    log_success "Rollback completed"
}

# Rollback to specific revision
rollback_to_revision() {
    local revision="$1"
    
    log_info "Rolling back to revision $revision in $NAMESPACE..."
    
    kubectl rollout undo deployment/app -n "$NAMESPACE" --to-revision="$revision"
    
    kubectl rollout status deployment/app -n "$NAMESPACE" --timeout=300s
    
    log_success "Rollback to revision $revision completed"
}

# Check deployment status
status() {
    log_info "Checking deployment status in $NAMESPACE..."
    
    echo ""
    echo "=== Deployment Status ==="
    kubectl get deployment app -n "$NAMESPACE" 2>/dev/null || echo "No deployment found"
    
    echo ""
    echo "=== Pods Status ==="
    kubectl get pods -n "$NAMESPACE" -l app=app
    
    echo ""
    echo "=== Recent Events ==="
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20
    
    echo ""
    echo "=== Replica Set Status ==="
    kubectl get rs -n "$NAMESPACE" -l app=app
}

# View logs
logs() {
    local tail="${1:-100}"
    
    log_info "Fetching logs from $NAMESPACE (last $tail lines)..."
    
    kubectl logs -n "$NAMESPACE" -l app=app --tail="$tail" --timestamps=true
}

# Follow logs in real-time
logs_follow() {
    log_info "Following logs from $NAMESPACE (Ctrl+C to stop)..."
    
    kubectl logs -n "$NAMESPACE" -l app=app -f --timestamps=true
}

# Run smoke tests
smoke_test() {
    log_info "Running smoke tests in $NAMESPACE..."
    
    local endpoint
    if [ "$NAMESPACE" == "production" ]; then
        endpoint="https://example.com"
    else
        endpoint="https://staging.example.com"
    fi
    
    echo "Testing health endpoint..."
    curl -sf "$endpoint/health" || {
        log_error "Health check failed"
        exit 1
    }
    
    echo "Testing ready endpoint..."
    curl -sf "$endpoint/ready" || {
        log_error "Ready check failed"
        exit 1
    }
    
    log_success "Smoke tests passed"
}

# Scale deployment
scale() {
    local replicas="$1"
    
    log_info "Scaling deployment to $replicas replicas..."
    
    kubectl scale deployment app -n "$NAMESPACE" --replicas="$replicas"
    
    kubectl rollout status deployment/app -n "$NAMESPACE" --timeout=300s
    
    log_success "Scaled to $replicas replicas"
}

# Restart deployment
restart() {
    log_info "Restarting deployment in $NAMESPACE..."
    
    kubectl rollout restart deployment/app -n "$NAMESPACE"
    
    kubectl rollout status deployment/app -n "$NAMESPACE" --timeout=300s
    
    log_success "Restart completed"
}

# Show help
show_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy <image_tag>        Deploy application with specified image tag"
    echo "  rollback                  Rollback to previous version"
    echo "  rollback-to <revision>    Rollback to specific revision"
    echo "  status                    Show deployment status"
    echo "  logs [lines]              View application logs (default: 100 lines)"
    echo "  logs-follow               Follow logs in real-time"
    echo "  smoke-test                Run smoke tests"
    echo "  scale <replicas>          Scale deployment to specified replicas"
    echo "  restart                   Restart deployment"
    echo "  help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy latest"
    echo "  $0 deploy v1.2.3"
    echo "  $0 rollback"
    echo "  $0 status"
    echo "  $0 logs 500"
    echo "  $0 scale 5"
}

# Main command handler
case "${1:-help}" in
    deploy)
        check_prerequisites
        deploy "$2"
        ;;
    rollback)
        check_prerequisites
        rollback
        ;;
    rollback-to)
        check_prerequisites
        rollback_to_revision "$2"
        ;;
    status)
        check_prerequisites
        status
        ;;
    logs)
        check_prerequisites
        logs "$2"
        ;;
    logs-follow)
        check_prerequisites
        logs_follow
        ;;
    smoke-test)
        smoke_test
        ;;
    scale)
        check_prerequisites
        scale "$2"
        ;;
    restart)
        check_prerequisites
        restart
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

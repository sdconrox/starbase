# Cluster Recovery Instructions

## Immediate Actions

The Calibre deployment has been removed from Git to prevent ArgoCD from redeploying it.

## Step 1: Access Master Node

SSH into the master node (10.60.0.198) using your normal credentials:

```bash
ssh <your-user>@10.60.0.198
```

## Step 2: Check System Resources

Check if the system is out of memory:

```bash
free -h
df -h
```

## Step 3: Check k3s Status

```bash
sudo systemctl status k3s
```

## Step 4: Check for Calibre Pods

If k3s is still running, try to access it directly:

```bash
sudo k3s kubectl get pods -A | grep calibre
```

If Calibre pods exist, delete them immediately:

```bash
sudo k3s kubectl delete namespace calibre --force --grace-period=0
```

## Step 5: Check Resource Usage

Check which pods are consuming the most resources:

```bash
sudo k3s kubectl top pods -A --sort-by=memory
```

## Step 6: Free Up Resources

If memory is exhausted, you may need to:

1. **Delete problematic pods:**
   ```bash
   sudo k3s kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
   ```

2. **Restart k3s service** (if needed):
   ```bash
   sudo systemctl restart k3s
   ```

3. **Check k3s logs for errors:**
   ```bash
   sudo journalctl -u k3s -n 100 --no-pager
   ```

## Step 7: Direct Container Runtime Access (When API Server is Down)

**If the API server is completely unresponsive, you can access containerd directly:**

k3s uses containerd as the container runtime. You can stop/remove containers directly without the API server:

1. **List all containers (including Calibre):**
   ```bash
   sudo crictl ps -a | grep calibre
   ```

2. **Stop Calibre containers directly:**
   ```bash
   # Find Calibre container IDs
   sudo crictl ps -a | grep calibre | awk '{print $1}' | xargs -r sudo crictl stop
   ```

3. **Remove Calibre containers:**
   ```bash
   # Remove stopped containers
   sudo crictl ps -a | grep calibre | awk '{print $1}' | xargs -r sudo crictl rm
   ```

4. **Alternative: Use containerd CLI directly:**
   ```bash
   # List containers
   sudo ctr -n k8s.io containers list | grep calibre

   # Stop containers (if running)
   sudo ctr -n k8s.io tasks kill <container-id> --signal SIGKILL

   # Remove containers
   sudo ctr -n k8s.io containers delete <container-id>
   ```

5. **Kill all Calibre processes directly:**
   ```bash
   # Find and kill Calibre processes
   sudo pkill -9 -f calibre
   ```

6. **Free up memory by killing high-memory containers:**
   ```bash
   # List all containers sorted by memory (if possible)
   sudo crictl stats

   # Or check system memory
   free -h

   # Kill specific high-memory containers
   sudo crictl stop <container-id>
   sudo crictl rm <container-id>
   ```

## Step 8: If k3s Won't Start

If k3s is completely down and won't start:

1. **Check if there's a memory leak in k3s itself:**
   ```bash
   ps aux | grep k3s
   ```

2. **Check system logs:**
   ```bash
   sudo dmesg | tail -50
   sudo journalctl -p err -n 50
   ```

3. **If OOM killer killed k3s:**
   - Free up memory on the system (use containerd commands above)
   - Restart k3s: `sudo systemctl restart k3s`

4. **Emergency: Stop all non-essential containers:**
   ```bash
   # Stop all containers except system pods
   sudo crictl ps -q | while read id; do
     name=$(sudo crictl inspect $id | grep -o '"name":"[^"]*"' | head -1)
     if [[ ! "$name" =~ (kube-system|kube-public|kube-node-lease) ]]; then
       sudo crictl stop $id || true
     fi
   done
   ```

## Step 9: Once Cluster is Recovered

1. **Commit the removal of Calibre files:**
   ```bash
   git add -A
   git commit -m "Emergency: Remove Calibre deployment causing cluster issues"
   git push
   ```

2. **Verify ArgoCD syncs and doesn't try to redeploy Calibre**

3. **Check all applications are healthy:**
   ```bash
   kubectl get pods -A
   ```

## Prevention

The Calibre linuxserver image is a desktop GUI application that can be very resource-intensive. For future deployments:
- Use lower resource limits
- Consider using a web-only Calibre solution instead
- Monitor resource usage before deploying heavy applications

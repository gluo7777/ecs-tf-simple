Service-level checks (via AWS CLI)

CLUSTER=ecs-simple-cluster
SERVICE=ecs-simple-nginx

# Service is active, desired == running, no pending tasks
aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region us-east-1 \
  --query 'services[0].{status:status,desired:desiredCount,running:runningCount,pending:pendingCount,events:events[0:3]}' --output json

# Look for "has reached a steady state" in the events above

Task-level checks

# Find the running task
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --region us-east-1 --query 'taskArns[0]' --output text)

# Task and container should both be RUNNING
aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region us-east-1 \
  --query 'tasks[0].{lastStatus:lastStatus,healthStatus:healthStatus,containers:containers[0].{name:name,lastStatus:lastStatus}}' --output json

# healthStatus shows UNKNOWN unless a container health check is defined in the task
# definition — that's expected here, not a problem.

Network reachability (the check that actually proves nginx is serving traffic)

# Resolve the task's ENI, then its public IP
ENI_ID=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region us-east-1 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --region us-east-1 \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

# Should return 200
curl -s -o /dev/null -w "HTTP status: %{http_code}\n" --max-time 8 "http://$PUBLIC_IP/"

What would still be unverified

| Component | Status |
|---|---|
| Stable endpoint (ALB/DNS) | Not set up — task's public IP changes on every restart/redeploy |
| Container health check | Not set up — `healthStatus` will always read UNKNOWN |
| HTTPS | Not set up — port 80 only |
| Autoscaling | Not set up — fixed `desired_count = 1` |

The service steady-state check and the curl to the task's public IP are the most
valuable quick verifications — if the service reports steady state and the curl
returns 200, the whole path (task launch, image pull, networking, nginx) is healthy.

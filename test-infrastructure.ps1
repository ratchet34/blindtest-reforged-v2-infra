# Simple Blindtest Infrastructure Test Script
Write-Host "Blindtest Reforged V2 Infrastructure Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Test counters
$TotalTests = 0
$PassedTests = 0

function Test-Component {
    param([string]$Name, [scriptblock]$Test)
    $global:TotalTests++
    Write-Host "Testing $Name..." -NoNewline
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host " PASS" -ForegroundColor Green
            $global:PassedTests++
        } else {
            Write-Host " FAIL" -ForegroundColor Red
        }
    } catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Minikube Status ===" -ForegroundColor Yellow

Test-Component "Minikube Running" {
    $status = minikube status --format='{{.Host}}' 2>$null
    return $status -eq "Running"
}

Write-Host ""
Write-Host "=== Namespace ===" -ForegroundColor Yellow

Test-Component "Namespace blindtest exists" {
    kubectl get namespace blindtest 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

Write-Host ""
Write-Host "=== Deployments ===" -ForegroundColor Yellow

$deployments = @("mongodb-deployment", "backend-deployment", "game-frontend-deployment", "admin-frontend-deployment", "mongo-express-deployment")
foreach ($deployment in $deployments) {
    Test-Component "Deployment $deployment ready" {
        $ready = kubectl get deployment $deployment -n blindtest -o jsonpath='{.status.readyReplicas}' 2>$null
        $desired = kubectl get deployment $deployment -n blindtest -o jsonpath='{.spec.replicas}' 2>$null
        return ($ready -eq $desired) -and ($ready -ne "")
    }
}

Write-Host ""
Write-Host "=== Services ===" -ForegroundColor Yellow

$services = @("mongodb-service", "backend-service", "game-frontend-service", "admin-frontend-service", "mongo-express-service")
foreach ($service in $services) {
    Test-Component "Service $service has ClusterIP" {
        $clusterIP = kubectl get service $service -n blindtest -o jsonpath='{.spec.clusterIP}' 2>$null
        return ![string]::IsNullOrEmpty($clusterIP) -and $clusterIP -ne "None"
    }
}

Write-Host ""
Write-Host "=== HTTP Endpoints ===" -ForegroundColor Yellow

Test-Component "Route / returns HTTP 200" {
    $response = curl.exe -s -o /dev/null -w "%{http_code}" "http://blindtest.local/" --max-time 10 2>$null
    return $response -eq "200"
}

Test-Component "Route /admin returns HTTP 200" {
    $response = curl.exe -s -o /dev/null -w "%{http_code}" "http://blindtest.local/admin" --max-time 10 2>$null
    return $response -eq "200"
}

Test-Component "Route /api returns HTTP 200" {
    $response = curl.exe -s -o /dev/null -w "%{http_code}" "http://blindtest.local/api" --max-time 10 2>$null
    return $response -eq "200"
}

Test-Component "Route /database requires auth" {
    $response = curl.exe -s -o /dev/null -w "%{http_code}" "http://blindtest.local/database" --max-time 10 2>$null
    return $response -eq "401"
}

Test-Component "Route /database accessible with auth" {
    $response = curl.exe -s -o /dev/null -w "%{http_code}" -u "admin:blindtest123" "http://blindtest.local/database" --max-time 10 2>$null
    return $response -eq "200"
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total tests: $TotalTests"
Write-Host "Passed: $PassedTests" -ForegroundColor Green
Write-Host "Failed: $($TotalTests - $PassedTests)" -ForegroundColor Red

$successRate = [math]::Round(($PassedTests * 100) / $TotalTests, 2)
Write-Host "Success rate: $successRate%"

if ($PassedTests -eq $TotalTests) {
    Write-Host ""
    Write-Host "All tests passed! Infrastructure is working correctly." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Some tests failed. Please check the infrastructure." -ForegroundColor Red
}

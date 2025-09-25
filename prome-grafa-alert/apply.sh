#！/bin/bash
kubectl create ns monitoring

for file in /prome-grafa-alert/*.yaml; do
    kubectl apply -f $file
done


echo "✅ 监控栈部署完成！"
echo ""
echo "🔄 端口转发命令："
echo "  去powershell执行：kubectl port-forward -n monitoring service/prometheus-service 19090:9090 &"
echo "  去powershell执行：kubectl port-forward -n monitoring service/grafana-service 13000:3000 &"
echo "  去powershell执行：kubectl port-forward -n monitoring service/alertmanager-service 19093:9093 &"
echo ""
echo "📊 访问地址："
echo "  Prometheus: http://localhost:19090"
echo "  Grafana: http://localhost:13000 (admin/admin123)"
echo "  Alertmanager: http://localhost:19093"

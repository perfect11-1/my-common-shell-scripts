#！/bin/bash
kubectl create ns logging

for file in /EFK/*.yaml; do
    kubectl apply -f $file
done


echo "✅ 日志栈部署完成！"
echo ""
echo "🔄 端口转发命令："
echo "  去powershell执行：kubectl port-forward -n logging service/elasticsearch-service 9200:9200 &"
echo "  去powershell执行：kubectl port-forward -n logging service/kibana-service 5601:5601 &"
echo ""
echo "📊 访问地址："
echo "  Elasticsearch: http://localhost:9200"
echo "  Kibana: http://localhost:5601"

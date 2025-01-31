package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	ctx := context.Background()
	kubeconfig := filepath.Join("kubeconfig")
	if _, err := os.Stat(kubeconfig); os.IsNotExist(err) {
		log.Fatal("kubeconfig file not found")
		return
	}
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		log.Fatal(err)
		return
	}
	fmt.Println(config.Host)
	client, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatal(err)
		return
	}
	for {
		time.Sleep(5 * time.Second)
		fmt.Println("Checking for pods")
		checkDeployments(ctx, client)
	}
}

func checkDeployments(ctx context.Context, client *kubernetes.Clientset) {
	namespacesToCheck := []string{"default", "kubernetes-dashboard"}
	for _, namespace := range namespacesToCheck {
		deployments, err := client.AppsV1().Deployments(namespace).List(ctx, metav1.ListOptions{})
		if err != nil {
			log.Fatal(err)
			return
		}
		for _, deployment := range deployments.Items {
			fmt.Printf("%s : %s\n", deployment.Namespace, deployment.Name)
			pods, err := client.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
				LabelSelector: fmt.Sprintf("app=%s", deployment.Spec.Selector.MatchLabels["app"]),
			})
			if err != nil {
				fmt.Printf("Failed getting pods: %v\n", err)
				continue
			}
			for _, pod := range pods.Items {
				if pod.Status.Phase == "CrashLoopBackOff" {
					fmt.Printf("Pod %s en état CrashLoopBackOff, redémarrage...\n", pod.Name)
					err := client.CoreV1().Pods(namespace).Delete(context.TODO(), pod.Name, metav1.DeleteOptions{})
					if err != nil {
						fmt.Printf("Failed deleting pod: %v\n", err)
					}
				}
			}
		}
	}
}

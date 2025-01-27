package main

import (
	"fmt"
	"os"
	"path/filepath"

	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	kubeconfig := filepath.Join("..", "kubeconfig")
	if _, err := os.Stat(kubeconfig); os.IsNotExist(err) {
		fmt.Println("kubeconfig file not found")
		return
	}
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(config.Host)
}

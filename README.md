# conf

[![CI-deploy](https://github.com/abcdesktopio/conf/actions/workflows/deploy.yml/badge.svg)](https://github.com/abcdesktopio/conf/actions/workflows/deploy.yml)

## Configuration files for abcdesktop

This repository contains sample configuration files and install scripts

## Test scripts

```
echo "Setup kubernetes"
git clone https://github.com/jfv-opensource/kube-tools.git
cd kube-tools && ./km --apply && cd ..
echo "Setup abcdesktop"
git clone https://github.com/abcdesktopio/conf.git
cd conf
kubernetes/install-3.1.sh --timeout 1800s 
echo "get pods"
kubectl get pods -n abcdesktop
kubernetes/samples/create_pod.sh
kubectl get pods -n abcdesktop
echo "pull applications"
kubernetes/pullapps-3.1.sh
echo "Run postman tests"
kubernetes/run_postmantest-3.1.sh
# done 
# uncomment to cleanup
# echo "Uninstall abcdesktop"
# kubernetes/uninstall-3.1.sh
# rm *.pem od.config abcdesktop.yaml poduser.yaml
```

## To get more informations

Please, read the public documentation web site:
* [https://www.abcdesktop.io](https://www.abcdesktop.io)
* [https://abcdesktopio.github.io/](https://abcdesktopio.github.io/)






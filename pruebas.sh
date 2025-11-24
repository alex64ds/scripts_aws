    aws elasticbeanstalk create-application-version \
        --application-name alex-app-cli \
        --version-label v1 \
        --description "Entorno Green" \
        --source-bundle S3Bucket="$namebucketg",S3Key="green.zip" \
        --auto-create-application

    echo "Se ha creado la aplicacion alex-app-cli v1"

    aws elasticbeanstalk create-environment \
        --application-name alex-app-cli \
        --environment-name alex-env-cli \
        --cname-prefix alex-app-cli \
        --version-label v1 \
        --solution-stack-name "64bit Amazon Linux 2023 v4.7.8 running PHP 8.4" \
        --option-settings Namespace=aws:autoscaling:launchconfiguration,OptionName=IamInstanceProfile,Value=LabInstanceProfile
    echo "Se ha creado el entorno alex-env-cli"

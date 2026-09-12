#用于自动登陆华东交通大学校园网


#安装
----
1. 下载 ecjtu_wifi_login.ps1 到任意目录
2. 右键点击 PowerShell，选择"以管理员身份运行"
3. 执行以下命令允许脚本运行（仅需一次）：
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

#操作流程：

交互式登录（首次使用，输入学号密码，且账号密码存储在本地）
.\ecjtu_wifi_login.ps1

自动登录（使用保存的凭据）
.\ecjtu_wifi_login.ps1 -Auto

保活模式（持续检测，断线自动重连，Ctrl+C 退出）
.\ecjtu_wifi_login.ps1 -KeepAlive

查询在线状态
.\ecjtu_wifi_login.ps1 -Status

注销下线
.\ecjtu_wifi_login.ps1 -Logout

直接指定账号密码
.\ecjtu_wifi_login.ps1 -Username "学号" -Password "密码"

指定运营商
.\ecjtu_wifi_login.ps1 -Auto -Carrier cmcc

#开机自动登录
------------
1. 按 Win+R，输入 shell:startup，回车打开启动文件夹
2. 新建 ecjtu_login.bat，内容如下：
   powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "脚本完整路径\ecjtu_wifi_login.ps1" -Auto
3. 重启电脑后自动登录
4. 取消：删除启动文件夹中的 ecjtu_login.bat

文件说明
--------
- ecjtu_wifi_login.ps1    主脚本
- ecjtu_wifi_config.json  凭据配置文件（自动生成）
- ecjtu_wifi_log.txt      运行日志（自动生成）

参数说明
--------
-Auto          自动登录，使用已保存的凭据
-Logout        注销下线
-Status        查询在线状态
-KeepAlive     保活模式，持续运行
-Username      指定学号
-Password      指定密码
-Carrier       运营商（cmcc/dx/lt/xyw），默认 cmcc
-KeepAliveInterval  保活检测间隔秒数，默认 120
-RetryCount    登录重试次数，默认 5
-RetryDelay    重试间隔秒数，默认 10

免责声明
--------
本脚本仅供学习交流使用，请遵守华东交通大学网络使用规范。
账号密码仅保存在本地，不会上传至任何服务器。

作者：Rac
开源协议：MIT

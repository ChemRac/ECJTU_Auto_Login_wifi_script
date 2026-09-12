ECJTU-Stu 校园网自动登录脚本
================================

华东交通大学 ECJTU-Stu 无线网络自动登录工具
基于 Dr.COM 认证系统，支持自动登录、断线重连、心跳保活

功能
----
- 自动登录：输入一次学号密码，之后一键登录
- 断线重连：网络断开后自动重新认证
- 心跳保活：持续检测网络状态，保持在线
- 状态查询：查看当前在线账号、流量、时长
- 注销下线：一键退出登录
- 凭据保存：学号密码加密保存到本地，下次免输入

环境要求
--------
- Windows 10 / 11
- PowerShell 5.1 或更高版本
- 已连接 ECJTU-Stu WiFi

安装
----
1. 下载 ecjtu_wifi_login.ps1 到任意目录
2. 右键点击 PowerShell，选择"以管理员身份运行"
3. 执行以下命令允许脚本运行（仅需一次）：
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

使用方法
--------

# 交互式登录（首次使用，输入学号密码）
.\ecjtu_wifi_login.ps1

# 自动登录（使用保存的凭据）
.\ecjtu_wifi_login.ps1 -Auto

# 保活模式（持续检测，断线自动重连，Ctrl+C 退出）
.\ecjtu_wifi_login.ps1 -KeepAlive

# 查询在线状态
.\ecjtu_wifi_login.ps1 -Status

# 注销下线
.\ecjtu_wifi_login.ps1 -Logout

# 直接指定账号密码
.\ecjtu_wifi_login.ps1 -Username "学号" -Password "密码"

# 指定运营商
.\ecjtu_wifi_login.ps1 -Auto -Carrier cmcc

运营商后缀说明
--------------
- 校园用户：@xyw
- 中国移动：@cmcc（默认）
- 中国电信：@dx
- 中国联通：@lt

开机自动登录
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

常见问题
--------

Q: 提示"Auth server unreachable"？
A: WiFi 刚连接时认证服务器需要几秒启动，脚本会自动等待最多 60 秒。如果持续失败，检查是否连接了正确的 WiFi。

Q: 提示"Login failed"？
A: 检查学号密码是否正确，运营商是否选择正确。

Q: 已在线但脚本还尝试登录？
A: 脚本会先检测是否在线，在线且网络正常则跳过登录。

Q: 如何删除保存的凭据？
A: 删除同目录下的 ecjtu_wifi_config.json 文件。

Q: 如何查看日志？
A: 打开同目录下的 ecjtu_wifi_log.txt。

技术说明
--------
- 认证服务器地址：172.16.2.100:801
- 登录接口：/eportal/?c=ACSetting&a=Login
- 注销接口：/eportal/?c=ACSetting&a=Logout&ver=1.0
- 状态查询：/eportal/?c=ACSetting&a=Query
- 认证系统：Dr.COM Web Portal
- 页面编码：GB2312

免责声明
--------
本脚本仅供学习交流使用，请遵守华东交通大学网络使用规范。
账号密码仅保存在本地，不会上传至任何服务器。

作者：Rac
开源协议：MIT

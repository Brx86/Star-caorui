curl -Lo /dev/null -skw "\
连接耗时: %{time_connect} s\n\
解析域名耗时: %{time_namelookup} s\n\
预连接耗时: %{time_pretransfer} s\n\
数据传输耗时: %{time_starttransfer} s\n\
重定向耗时: %{time_redirect} s\n\
下载速度: %{speed_download} B/s\n\
总耗时: %{time_total} s\n\n" $1
<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
$state = __DIR__ . '/.tv4-http.tmp';
$mode = $argv[1] ?? 'test';
$db = new PDO('mysql:host=127.0.0.1;charset=utf8mb4', getenv('SOLARIS_DB_USER') ?: 'root', getenv('SOLARIS_DB_PASSWORD') ?: '', [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
if ($mode === 'setup') {
    if (is_file($state)) { throw new RuntimeException('Hãy cleanup phiên thử nghiệm trước.'); }
    $name = 'solaris_tv4_http_' . bin2hex(random_bytes(6));
    $schema = file_get_contents(dirname(__DIR__) . '/database/tv4-installation.sql');
    $db->exec(str_replace(['CREATE DATABASE IF NOT EXISTS solaris ', 'USE solaris;'], ["CREATE DATABASE IF NOT EXISTS {$name} ", "USE {$name};"], $schema));
    $db->exec(file_get_contents(dirname(__DIR__) . '/database/tv4-billing.sql'));
    $db->exec(str_replace('USE solaris;', "USE {$name};", file_get_contents(dirname(__DIR__) . '/database/tv4-demo.sql')));
    file_put_contents($state,$name);
    echo $name;
    exit;
}
$name = trim(file_get_contents($state));
if (!preg_match('/^solaris_tv4_http_[a-f0-9]{12}$/D',$name)) { throw new RuntimeException('Invalid test database.'); }
$db->exec("USE `{$name}`");
if ($mode === 'cleanup') {
    foreach ($db->query('SELECT file_path FROM project_documents')->fetchAll(PDO::FETCH_COLUMN) as $path) {
        $root = realpath(dirname(__DIR__) . '/assets/uploads/installation');
        $file = realpath(dirname(__DIR__) . '/' . $path);
        if ($root && $file && str_starts_with($file,$root . DIRECTORY_SEPARATOR)) { unlink($file); }
    }
    $db->exec("DROP DATABASE `{$name}`");
    unlink($state);
    exit("Đã xóa dữ liệu thử nghiệm.\n");
}
$url = 'http://127.0.0.1:8765/index.php?page=installations';
$cookies = tempnam(sys_get_temp_dir(),'tv4cookies');
$curl = curl_init();
curl_setopt_array($curl,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_COOKIEFILE=>$cookies,CURLOPT_COOKIEJAR=>$cookies,CURLOPT_TIMEOUT=>15]);
$http = static function (string $suffix='', ?array $data=null) use($curl,$url): array {
    curl_setopt($curl,CURLOPT_URL,$url.$suffix);
    curl_setopt($curl,CURLOPT_POST,$data!==null);
    if ($data!==null) { curl_setopt($curl,CURLOPT_POSTFIELDS,$data); }
    $body=curl_exec($curl);
    if ($body===false) { throw new RuntimeException(curl_error($curl)); }
    if (str_contains($body,'Fatal error') || str_contains($body,'Warning:')) { throw new RuntimeException('PHP error: '.$body); }
    return [curl_getinfo($curl,CURLINFO_HTTP_CODE),$body];
};
$check = static function(bool $ok,string $message):void {if(!$ok)throw new RuntimeException('FAIL: '.$message); echo "PASS HTTP: {$message}\n";};
$csrf = static function(string $html):string {preg_match('/name="csrf" value="([a-f0-9]+)"/',$html,$match);return $match[1]??'';};
$png = tempnam(sys_get_temp_dir(),'tv4png');
$bad = tempnam(sys_get_temp_dir(),'tv4bad');
$large = tempnam(sys_get_temp_dir(),'tv4large');
file_put_contents($png,base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jwWQAAAAASUVORK5CYII='));
file_put_contents($bad,'<?php echo "bad";');
file_put_contents($large,str_repeat('x',5*1024*1024+1));
try {
    [$code,$body]=$http(); $check($code===200 && str_contains($body,'Đăng nhập theo dõi dự án') && str_contains($body,'Quyền lợi khi theo dõi dự án'),'Khách chưa đăng nhập xem quy trình, quyền lợi và form đăng nhập');
    $token=$csrf($body);
    [$code,$body]=$http('', ['action'=>'login','csrf'=>'wrong','username'=>'admin.tv4','password'=>'Solaris@2026']);
    $check(str_contains($body,'Phiên biểu mẫu hết hạn'),'Chặn CSRF sai');
    [$code]=$http('', ['action'=>'login','csrf'=>$token,'username'=>'admin.tv4','password'=>'Solaris@2026']);
    $check($code===303,'Đăng nhập quản lý và chuyển hướng');
    [$code,$body]=$http('&project=1'); $token=$csrf($body);
    $check($code===200 && str_contains($body,'Phân công &amp; bắt đầu dự án') && str_contains($body,'tv4-booking'),'Render chi tiết và lịch phân công');
    [$code]=$http('&project=1',['action'=>'assign','csrf'=>$token,'start_date'=>'2026-11-02','end_date'=>'2026-11-20','technicians[0]'=>'4','technicians[1]'=>'5','hours_per_day'=>'4']);
    $check($code===303,'Gửi form phân công nhóm');
    [$code,$body]=$http('&project=1');
    $check(str_contains($body,'Phạm Ngọc Chi') && str_contains($body,'Võ Anh Dũng'),'Hiển thị nhóm vừa phân công');
    $http('', ['action'=>'logout','csrf'=>$csrf($body)]);
    [, $body]=$http();
    $http('', ['action'=>'login','csrf'=>$csrf($body),'username'=>'kythuat.an','password'=>'Solaris@2026']);
    [, $body]=$http('&project=1');
    $check(str_contains($body,'không còn được phân công'),'Chặn truy cập dự án người khác');
    [, $body]=$http('&project=2'); $token=$csrf($body);
    $check(str_contains($body,'Yêu cầu duyệt giai đoạn') && !str_contains($body,'Duyệt &amp; mở bước tiếp theo'),'Đúng thao tác kỹ thuật viên');
    $http('&project=2',['action'=>'upload','csrf'=>$token,'document_type'=>'stage_photo','document'=>new CURLFile($bad,'image/png','fake.png')]);
    [, $body]=$http('&project=2');
    $check(str_contains($body,'đúng định dạng'),'Từ chối file giả ảnh');
    $http('&project=2',['action'=>'upload','csrf'=>$token,'document_type'=>'stage_photo','document'=>new CURLFile($large,'image/png','large.png')]);
    [, $body]=$http('&project=2');
    $check(str_contains($body,'5MB'),'Từ chối file vượt 5MB');
    $http('&project=2',['action'=>'upload','csrf'=>$token,'document_type'=>'stage_photo','document'=>new CURLFile($png,'image/png','evidence.png')]);
    [, $body]=$http('&project=2');
    $check(str_contains($body,'evidence.png'),'Upload ảnh qua multipart thực tế');
    $id=(int)$db->query('SELECT MAX(id) FROM project_documents')->fetchColumn();
    [$code,$body]=$http('&document='.$id.'&preview=1');
    $check($code===200 && str_starts_with($body,"\x89PNG"),'Xem ảnh qua route kiểm tra quyền');
    $http('&project=2',['action'=>'upload','csrf'=>$token,'document_type'=>'stage_photo','document'=>new CURLFile($png,'image/png','same.png')]);
    [, $body]=$http('&project=2');
    $check(str_contains($body,'cùng nội dung'),'Chống trùng theo hash nội dung');
    $http('&project=2',['action'=>'submit_stage','csrf'=>$token]);
    [, $body]=$http('&project=2');
    $check($db->query("SELECT status FROM project_stages WHERE project_id=2 AND stage='survey'")->fetchColumn()==='pending_approval' && str_contains($body,'Chờ duyệt'),'Gửi duyệt giai đoạn qua HTTP');
    $http('', ['action'=>'logout','csrf'=>$csrf($body)]);
    [, $body]=$http();
    $http('', ['action'=>'login','csrf'=>$csrf($body),'username'=>'kythuat.dung','password'=>'Solaris@2026']);
    [, $body]=$http('&document='.$id);
    $check(str_contains($body,'không còn được phân công'),'Chặn tải tài liệu dự án người khác');
    $http('', ['action'=>'logout','csrf'=>$csrf($body)]);
    [, $body]=$http();
    [$code]=$http('', ['action'=>'login','csrf'=>$csrf($body),'username'=>'khachhang.demo','password'=>'Solaris@2026']);
    $check($code===303,'Đăng nhập bằng tài khoản khách hàng');
    [, $body]=$http();
    $check(str_contains($body,'Dự án của tôi') && str_contains($body,'SOLAR-2026-001') && str_contains($body,'SOLAR-2026-003'),'Khách hàng xem danh sách dự án của mình');
    [, $body]=$http('&project=2');
    $token=$csrf($body);
    $check(str_contains($body,'customer-stage-6') && !str_contains($body,'name="document"') && !str_contains($body,'Yêu cầu duyệt giai đoạn') && !str_contains($body,'Nhật ký dự án'),'Chi tiết khách hàng có sáu bước và không có điều khiển nội bộ');
    $before=$db->query('SELECT status FROM project_stages WHERE id=7')->fetchColumn();
    foreach (['assign','upload','submit_stage','approve_stage','reject_stage','postpone','replacement','approve_request','reject_request'] as $action) {
        $http('&project=2',['action'=>$action,'csrf'=>$token]);
        [, $body]=$http('&project=2');
        $check(str_contains($body,'không có quyền thực hiện'),'Máy chủ từ chối POST khách hàng: '.$action);
    }
    $check($db->query('SELECT status FROM project_stages WHERE id=7')->fetchColumn()===$before,'POST giả không đổi trạng thái giai đoạn');
    $remaining = (string) (int) round((float) $db->query('SELECT total_amount FROM projects WHERE id=2')->fetchColumn() * 100);
    $payment = ['action'=>'pay_project','csrf'=>$token,'expected_remaining'=>$remaining,'confirm_simulation'=>'1'];
    $http('&project=2',array_merge($payment,['csrf'=>'wrong']));
    $check((int)$db->query('SELECT COUNT(*) FROM project_payments')->fetchColumn()===0,'CSRF sai không ghi thanh toán');
    [$code]=$http('&project=2',$payment);
    [, $body]=$http('&project=2');
    $check($code===303 && str_contains($body,'Thanh toán mô phỏng thành công') && str_contains($body,'Đã thanh toán đủ'),'Thanh toán mô phỏng qua form khách hàng');
    $http('&project=2',$payment);
    $check((int)$db->query('SELECT COUNT(*) FROM project_payments')->fetchColumn()===1,'Gửi form thanh toán lặp không ghi trùng');
    [, $body]=$http('&project=2&invoice=1');
    $check(str_contains($body,'Chỉ in hóa đơn từ bước'),'Route in chặn trước mua sắm');
    $db->exec("UPDATE project_stages SET status='approved' WHERE project_id=2 AND stage IN ('survey','design')");
    $db->exec("UPDATE project_stages SET status='in_progress' WHERE project_id=2 AND stage='procurement'");
    $db->exec("UPDATE projects SET current_stage='procurement' WHERE id=2");
    [, $body]=$http('&project=2&invoice=1');
    $check(str_contains($body,'SOLARIS — HÓA ĐƠN DỰ ÁN') && str_contains($body,'window.print()') && !str_contains($body,'tv4-projects'),'Route hóa đơn trả trang in riêng');
    [, $body]=$http('&document='.$id);
    $check(str_contains($body,'khu vực xử lý nội bộ'),'Khách hàng không tải hồ sơ nội bộ bằng URL trực tiếp');
    $db->exec("INSERT INTO projects (contract_code,user_id,project_name,capacity_kwp,total_amount,installation_address) VALUES ('PRIVATE-OTHER',1,'Du an rieng',5,50000000,'Dia chi rieng')");
    $otherId=(int)$db->lastInsertId();
    [, $body]=$http();
    $check(!str_contains($body,'PRIVATE-OTHER'),'Danh sách khách hàng không lộ dự án chủ sở hữu khác');
    [, $body]=$http('&project='.$otherId);
    $check(str_contains($body,'không có quyền xem') && !str_contains($body,'Dia chi rieng'),'Chặn IDOR qua URL chi tiết khách hàng');
    [, $body]=$http('&project='.$otherId.'&invoice=1');
    $check(!str_contains($body,'SOLARIS — HÓA ĐƠN DỰ ÁN') && !str_contains($body,'Dia chi rieng'),'Chặn IDOR route hóa đơn');
    $http('', ['action'=>'logout','csrf'=>$csrf($body)]);
    [, $body]=$http();
    $http('', ['action'=>'login','csrf'=>$csrf($body),'username'=>'admin.tv4','password'=>'Solaris@2026']);
    $db->exec("INSERT INTO categories (name,slug) VALUES ('Test billing','test-billing')");
    $categoryId=(int)$db->lastInsertId();
    $db->exec("INSERT INTO products (category_id,product_code,name,price) VALUES ({$categoryId},'HTTP-BILLING','Vật tư HTTP',150000)");
    $productId=(int)$db->lastInsertId();
    [, $body]=$http('&project=2');
    $check(str_contains($body,'Bổ sung vật tư') && str_contains($body,'Vật tư HTTP'),'Admin có form vật tư sau khảo sát');
    [$code]=$http('&project=2',['action'=>'add_material','csrf'=>$csrf($body),'product_id'=>$productId,'quantity'=>2,'material_reason'=>'Phát sinh HTTP']);
    [, $body]=$http('&project=2');
    $check($code===303 && str_contains($body,'Phát sinh HTTP') && str_contains($body,'300.000'),'Form vật tư ghi dữ liệu và cập nhật chi phí');
    $http('', ['action'=>'logout','csrf'=>$csrf($body)]);
    [, $body]=$http();
    $http('', ['action'=>'login','csrf'=>$csrf($body),'username'=>'kythuat.an','password'=>'Solaris@2026']);
    [, $body]=$http('&project=2');
    $check(str_contains($body,'Bổ sung vật tư') && str_contains($body,'In hóa đơn'),'Kỹ thuật viên được gán thấy vật tư và nút in tại mua sắm');
    echo "Kiểm tra HTTP hoàn thành. Chạy cleanup sau khi kiểm tra trình duyệt.\n";
} finally { curl_close($curl); unlink($cookies); unlink($png); unlink($bad); unlink($large); }

<?

header("Expires: Mon, 25 Jan 1970 05:00:00 GMT");   
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT"); 
header("Cache-Control: no-store, no-cache, must-revalidate");  
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");

$TEMP_FOLDER = 'temp/';


// Different file fields
if (isset($_FILES['Filedata'])) {
	$fileName = $_POST['test'];
	$filePath = $TEMP_FOLDER.basename($fileName);
	$filePath2 = $TEMP_FOLDER.basename($_FILES['Filedata2']['name']);
	move_uploaded_file($_FILES['Filedata']['tmp_name'], $filePath);
	move_uploaded_file($_FILES['Filedata2']['tmp_name'], $filePath2);
}


/*
// Multiply Filedata
foreach ($_FILES["Filedata"]["error"] as $key => $error) {
    if ($error == UPLOAD_ERR_OK) {
        $tmp_name = $_FILES["Filedata"]["tmp_name"][$key];
        $name = $_FILES["Filedata"]["name"][$key];
        $filePath = $TEMP_FOLDER.basename($name);
        move_uploaded_file($tmp_name, $filePath);
    }
}
*/

print "result=" . urlencode("File Received");
exit(0);

?>
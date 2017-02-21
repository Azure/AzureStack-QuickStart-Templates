$(document).ready(function () {
	loadAccountInfo();
});

function loadAccountInfo() {
	$.getJSON("/storage.json", function (data) {
		if (data) {
			$("#account").val(data.accountName);
			$("#key").val(data.accountKey);
			$("input[type='radio'][name='host'][value='" + data.endpoint + "']").attr("checked", "checked");
		}
	});
}
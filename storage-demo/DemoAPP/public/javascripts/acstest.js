var interval;
var result = false;
var total = 1;
$(document).ready(function () {
	interval = setInterval("updateStatus()", 500);
	total = $("#cases li").length;
	loadAccountInfo();
});

function loadAccountInfo(){
	console.log("loadAccountInfo");
	$.getJSON("/storage.json", function(data){
		console.log(data);
	});
}


function updateStatus() {
	$.post("/result", { 'key': $('#key').val(), 'account': $('#account').val(), 'host': $('#host').val() }, function (json) {
		result = JSON.parse(json);
	});
	if (!result) return;
	var finished = 0;
	var ok = 0;
	var error = 0;
	$("span.desc").click(function () {
		var casename = $(this).attr("case");
		$("#output").html($(this).text().trim() + ":\n" + result[casename][1]);
	});
	$("#cases li").each(function () {
		var casename = $(this).attr("case");
		if (result[casename]) {
			$(this).find("span.desc").addClass("a");
			finished++;
			if (result[casename][0] == 0) {
				$(this).find(".status-ok").removeClass("hidden");
				$(this).find(".status-error").addClass("hidden");
				ok++;
			}
			else {
				$(this).find(".status-error").removeClass("hidden");
				$(this).find(".status-ok").addClass("hidden");
				error++;
			}
		}
	});
	var progress = Math.floor(finished * 100 / total);
	$('[role="progressbar"]').html(progress + "%");
	$('[role="progressbar"]').css("width", progress + "%");
	$('[role="progressbar"]').attr('aria-valuenow', progress);
	if (finished == total) {
		clearInterval(interval);
		var classname = "progress-bar-success";
		if (ok == 0 && error > 0) classname = "progress-bar-danger";
		if (ok > 0 && error > 0) classname = "progress-bar-warning";
		$('[role="progressbar"]').removeClass("active");
		$('[role="progressbar"]').addClass(classname);
		$('[role="progressbar"]').removeClass("progress-bar-striped");
	}
}


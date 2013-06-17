// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require_tree .

$(function() {
    $("#nav").find("li").each(function() {
        $(this).mouseenter(function() {
            $(this).find("ul").each(function() {
                var offset = $(this).siblings("a").addClass("hover").offset();
                var height = $(this).parent().height();
                $(this).offset({ top: offset.top + height, left: offset.left });
            });
        });

        $(this).mouseleave(function() {
            $(this).find("ul").each(function() {
                $(this).siblings("a").removeClass("hover");
                $(this).offset({ top: -9999, left: -9999 });
            });
        });
    });
});
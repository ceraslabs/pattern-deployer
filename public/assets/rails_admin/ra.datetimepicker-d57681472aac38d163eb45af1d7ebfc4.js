/*
 * RailsAdmin date/time picker @VERSION
 *
 * License
 *
 * http://www.railsadmin.org
 *
 * Depends:
 *   jquery.ui.core.js
 *   jquery.ui.widget.js
 *   jquery.ui.datepicker.js
 *   jquery.ui.timepicker.js (http://plugins.jquery.com/project/timepicker-by-fgelinas)
 */
(function(e){e.widget("ra.datetimepicker",{options:{showDate:!0,showTime:!0,datepicker:{},timepicker:{}},_create:function(){var t=this;this.element.hide(),this.options.showTime&&(this.timepicker=e('<input class="TIMEPICKER" type="text" value="'+this.options.timepicker.value+'" />'),this.timepicker.css("width","60px"),this.timepicker.insertAfter(this.element),this.timepicker.bind("change",function(){t._onChange()}),this.timepicker.timepicker(this.options.timepicker)),this.options.showDate&&(this.datepicker=e('<input type="text" value="'+this.options.datepicker.value+'" />'),this.datepicker.css("margin-right","10px"),this.datepicker.insertAfter(this.element),this.datepicker.bind("change",function(){t._onChange()}),this.datepicker.datepicker(this.options.datepicker))},_onChange:function(){var e=[];this.options.showDate&&e.push(this.datepicker.val()),this.options.showTime&&e.push(this.timepicker.val()),this.element.val(e.join(" "))}})})(jQuery);
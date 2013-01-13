/*
jQuery Wiggle
Author: WonderGroup, Jordan Thomas
URL: http://labs.wondergroup.com/demos/mini-ui/index.html
License: MIT (http://en.wikipedia.org/wiki/MIT_License)
*/
jQuery.fn.wiggle=function(e){var t={speed:50,wiggles:3,travel:5,callback:null},e=jQuery.extend(t,e);return this.each(function(){var t=this,n=jQuery(this).wrap('<div class="wiggle-wrap"></div>').css("position","relative"),r=0;for(i=1;i<=e.wiggles;i++)jQuery(this).animate({left:"-="+e.travel},e.speed).animate({left:"+="+e.travel*2},e.speed*2).animate({left:"-="+e.travel},e.speed,function(){r++,jQuery(t).parent().hasClass("wiggle-wrap")&&jQuery(t).parent().replaceWith(t),r==e.wiggles&&jQuery.isFunction(e.callback)&&e.callback()})})};
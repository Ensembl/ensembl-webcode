/*
 * Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

Ensembl.Panel.TextSequence = Ensembl.Panel.Content.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('dataTableRedraw', this, this.initPopups);
    Ensembl.EventManager.register('ajaxComplete',    this, this.sequenceKey);
    Ensembl.EventManager.register('ajaxLoaded',      this, this.panelLoaded);
    Ensembl.EventManager.register('getSequenceKey',  this, this.getSequenceKey);
  },
  
  init: function () {
    var panel = this;
    
    this.popups = {};
    this.zmenuId = 1;
    
    this.base();
    this.initPopups();
    
    if (!Ensembl.browser.ie) {
      $('pre > [title]', this.el).helptip({ track: true });
    }
    
    this.el.on('mousedown', '.info_popup', function () {
      $(this).css('zIndex', ++Ensembl.PanelManager.zIndex);
    }).on('click', '.info_popup .close', function () {
      $(this).parent().hide();
    }).on('click', 'pre span.tsmain a', function (e) {
        panel.makeZMenu(e, $(this));
        return false;
    });
  },
  
  initPopups: function () {
    var panel = this;
    
    $('.info_popup', this.el).hide();
    
    $('pre span.tsmain a', this.el).each(function () {
      if (!panel.popups[this.href]) {
        panel.popups[this.href] = 'zmenu_' + panel.id + '_' + (panel.zmenuId++);
      }
      
      $(this).data('menuId', panel.popups[this.href]); // Store a single reference <a> for all identical hrefs - don't duplicate the popups
    });
  },
  
  makeZMenu: function (e, el) {
    Ensembl.EventManager.trigger('makeZMenu', el.data('menuId'), { event: e, area: { a: el } });
  },
  
  sequenceKey: function () {
    if (!$('.sequence_key', this.el).length) {
      var key = Ensembl.EventManager.trigger('getSequenceKey');
      
      if (!key) { 
        return;
      }
      
      var params = {};
      
      $.each(key, function (id, k) {
        $.extend(true, params, k);
      });
      
      var urlParams = $.extend({}, params, { variations: [], exons: [] });
      
      $.each([ 'variations', 'exons' ], function () {
        for (var p in params[this]) {
          urlParams[this].push(p);
        }
      });
      
      this.getContent(this.params.updateURL.replace(/sub_slice\?/, 'key?') + ';' + $.param(urlParams, true), this.el.parent().siblings('.sequence_key'));
    }
  },
  
  getSequenceKey: function () {
    Ensembl.EventManager.unregister('ajaxComplete', this);
    return JSON.parse($('.sequence_key_json', this.el).html() || false);
  },

  expandStretch: function(s) {
    var out = [],c,repl,newest=-1,recent=[],i,j,nr;
    var digit = /^\d$/;

    var repl = {
      'Z': '>>',
      'Y': '>b',
      'X': 'VVVVV',
      'W': 'UUUUU',
      'V': 'TTT',
      'U': 'QQQ',
      'T': 'aaa',
      'S': 'aaaa',
      'R': 'aaaaa',
      'Q': 'aaaaaaaaaa',
      'G': 'FFFFF',
      'F': 'EEEEE',
      'E': 'DDD',
      'D': 'CCC',
      'C': 'AAA',
      'B': '>>>>>',
      'A': '>>>>>>>>>>'
    }
    
    while(s.length) {
      c = s.charAt(0);
      s = s.substr(1);
      if(c in repl) {
        s = repl[c]+s;
        continue;
      }
      if(c == '>') {
        i = ++newest;
      } else if(c == '[') {
        i = 0;
        while(digit.test(s.charAt(0))) {
          i = i*10+(s.charCodeAt(0)-'0'.charCodeAt(0));
          s = s.substr(1);
        }
        newest = i;
      } else {
        i = recent[c.charCodeAt(0)-'a'.charCodeAt(0)];
      }
      out.push(i);
      nr = [i];
      for(j=0;j<recent.length && j<24;j++) {
        if(recent[j] != i) {
          nr.push(recent[j]);
        }
      }
      recent = nr; 

    }
    return out;
  },

  buildKeys: function(data) {
    var j,out = [];
    var prefixes = this.expandStretch(data.lengthstr);
    var prev = "";

    for(j=0;j<prefixes.length && j<data.suffixes.length;j++) {
      var str = prev.substr(0,data.lengths[prefixes[j]])+data.suffixes[j];
      out.push(str)
      prev = str;
    }
    return out;
  },

  markupSequence: function(data,$el,i) {
    var panel = this;
    var j,states,p,empty,empty_state=-1,statestart=-1,values,seq,newstate;

    values = [];
    seq = [];
    $.each(data.keys,function(k,v) {
      values[k] = panel.buildKeys(v);
      seq[k] = panel.expandStretch(v.main);
    });

    states = this.expandStretch(data.main);
    states.push({});
    p = -1;
    for(j=0;j<states.length;j++) {
      if(states[j] == empty_state) {
        1; //
      } else if(states[j] != p) {
        empty = 1;
        $.each(data.keys,function(k,v) {
          if(values[k][seq[k][states[j]]]) { empty = 0; } 
        });
        if(empty) { empty_state = states[j]; }
        p = states[j];
      }
      if(states[j] == empty_state && statestart != -1) {
        newstate = {}
        $.each(data.keys,function(k,v) {
          newstate[k] = values[k][seq[k][states[statestart]]];
        });
        console.log(JSON.stringify(newstate),statestart,j);
        statestart = -1;
      } else if(states[j] != empty_state && statestart == -1) {
        statestart = j;
      }
    }
  },

  panelLoaded: function() {
    var panel = this;

    Ensembl.EventManager.unregister('ajaxLoaded', this);
    $('.stretch_data',this.el).each(function() {
      var i;
      var data = $.parseJSON($(this).text());
      for(i=0;i<data.length;i++) {
        panel.markupSequence(data[i],$(this),i);
      }
    });
  }

});

import moment from 'moment'
import {i18n, i18n_c, i18n_nop} from 'app/utils/i18n'
import templates from './templates'

export {templates}

/// Convert a list of key,value into an object
export function to_map(l){
  let d={}
  for(let kv of l)
    d[kv[0]]=kv[1]
  return d
}
/// Convert an object to a list of [k,v]
export function to_list(d){
  let l=[]
  for (let k in d){
    l.push([k, d[k]])
  }
  return l
}

export function dedup(l){
  let ret=[]
  for (let i of l){
    if (ret.indexOf(i)<0)
      ret.push(i)
  }
  return ret
}

export function flatmap( arr, fn ){
  let ret=[]
  for(let el of arr.map( fn ))
    ret = ret.concat(el)
  return ret
}

export function is_empty(l){
  return !l || (l.length==0)
}

/// Drops some keys from a map, and returns a copy without these keys
/// Its optimized for a small ammount of keys O(N²)
export function map_drop(map, keys){
  if (keys.length==0)
    return map

  let r={}
  for (let k in map){
    let v=map[k]
    let drop=false;
    for(let dk of keys){
      if (dk==k){
        drop=true;
        break;
      }
    }
    if (!drop)
      r[k]=v
  }
  return r
}

/// Gets a deep value from a map, following a path. If any if null/undefined, returns that, not continuing the path. Path is a list
export function map_get(obj, path){
  let v = obj[path[0]]
  if (v && path.length>1)
    return map_get(v, path.slice(1))
  return v
}

/// Updates a dict path element with the given value. Path is a list of tranversal.
export function map_set(orig, path, value){
  if (path.length==0)
    return value
  const head = path[0]
  const rest = path.slice(1)
  return merge(orig, {[head]: map_set( orig[head], rest, value )})
}

/// Concatenates lists returning a new one
export function concat(/* arguments */){
  let ret = []
  for (let l of arguments){
    for (let x of l)
      ret.push(x)
  }
  return ret
}

export function sort_by_name(list){
  return list.slice().sort( (a,b) => (a.name || "").localeCompare(b.name || "") )
}

const color_set=["red","orange","yellow","olive","green","teal","blue","violet","purple","pink","brown","grey"]
const fixed_colors={
  "stopped" : "lightgrey",
  "running" : "green",
  "unknown" : "grey",
  "error" : "red",
  "ok" : "green",
  "warning" : "orange",
  "up" : "green",
  "down" : "red",
  "important" : "red",
  "new" : "green",
  "unread" : "yellow",
  "disabled" : "grey",
  "active" : "green",
  "broken" : "red",
  "updatable" : "yellow",
  "": "grey"
}

export function colorize(str){
  if (!str)
    return "red"
  str=str.toLowerCase()
  if (fixed_colors[str])
    return fixed_colors[str]
  return random_color(str)
}

/// Returns a random nice color for the logo icon
export function random_color(str){
  // From http://stackoverflow.com/questions/7616461/generate-a-hash-from-string-in-javascript-jquery
  // http://werxltd.com/wp/2010/05/13/javascript-implementation-of-javas-string-hashcode-method/
  function hash(str) {
    var hash = 0, i, chr, len;
    if (str.length === 0) return hash;
    for (i = 0, len = str.length; i < len; i++) {
      chr   = str.charCodeAt(i);
      hash  = ((hash << 5) - hash) + chr;
      hash |= 0; // Convert to 32bit integer
    }
    return Math.abs(hash);
  };

  return color_set[hash(str)%color_set.length]
}

// http://stackoverflow.com/questions/1026069/how-do-i-make-the-first-letter-of-a-string-uppercase-in-javascript
export function capitalize(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

/// Merges two or more dicts into a new one. Do not modify origins. B items have priority.
export function merge(){
  if (Array.isArray(arguments[0])){
    let args=[[], ...arguments]
    return Array.concat.apply(null, args)
  }
  else{
    let args=[{}, ...arguments]
    return Object.assign.apply(null, args)
  }
}

export function object_is_equal(a,b){
  if (a == b) // Fast comparison, for object always false
    return true
  if (a == undefined || b == undefined) // Only one, (see prev comparison), so !=
    return false
  for(let k in a){
    if (!b.hasOwnProperty(k))
      return false
    let v=a[k]
    switch(typeof(v)){
      case 'object':
        if (!object_is_equal(v, b[k]))
          return false
      break;
      case 'function': // Ignore fns
      break;
      default:
        if (v!=b[k])
          return false
      break;
    }
  }
  // Now check also all props of b are in a
  for(let k in b){
    if (!a.hasOwnProperty(k))
      return false
  }
  return true
}

const timeunits={
  millisecond: 1,
  second: 1000,
  minute: 1000 * 60,
  hour: 1000 * 60 * 60,
  day: 1000 * 60 * 60 * 24,
  MAX: 1000 * 60 * 60 * 24 * 14
}
const one_day=(24*60*60)

i18n_nop("millisecond")
i18n_nop("second")
i18n_nop("minute")
i18n_nop("hour")
i18n_nop("day")

export function pretty_ago(t, now, minres="second"){
  now = moment.utc(now)
  let other = moment.utc(t)
  if (minres && typeof(minres)=="string")
    minres=timeunits[minres]

  let timediff = now.diff(other)

  if (timediff>timeunits.MAX){
    return pretty_date(other, minres)
  }

  let lastunit='millisecond'
  for (let d in timeunits){
    if (timediff >= timeunits[d])
      lastunit=d
  }
  if (timeunits[lastunit] < minres){
    if (minres >= (timeunits["day"]))
      return i18n("today")
    return i18n("now")
  }
  let units
  if (lastunit=="day"){
    // if days, must check on day boundaries, not 24h chunks;
    // 24h+1m ago could be 2 days ago, not yesterday
    units = Math.floor(now.unix() / one_day) - Math.floor(other.unix() / one_day)

    if (units==0)
      return i18n('today')
    if (units==1)
      return i18n('yesterday')
  }
  else{
    units=Math.floor(timediff / timeunits[lastunit])
  }
  const s=units > 1 ? 's' : ''
  let expr=i18n("{units} {timeunit} ago", {units, timeunit: `${i18n(lastunit)}${s}` })
  return expr
}

export function pretty_date(d, precission){
  if (precission >= timeunits.day )
    return moment(d).format("ddd, ll")
  return moment(d).format("llll")
}

export const months = [
    i18n_nop("January"),
    i18n_nop("February"),
    i18n_nop("March"),
    i18n_nop("April"),
    i18n_nop("May"),
    i18n_nop("June"),
    i18n_nop("July"),
    i18n_nop("August"),
    i18n_nop("September"),
    i18n_nop("October"),
    i18n_nop("November"),
    i18n_nop("December")
  ]

export const days = [
  i18n_nop("Sunday"),
  i18n_nop("Monday"),
  i18n_nop("Tuesday"),
  i18n_nop("Wednesday"),
  i18n_nop("Thursday"),
  i18n_nop("Friday"),
  i18n_nop("Saturday"),
  i18n_nop("Sunday"),
]

export function unwrap(fn, arg1, arg2){ // If two args, use them, if one, use store.getState() and props, if none, use store.getState and this.props.
  if (!fn) // not existant is as an empty list
    return []
  if (typeof(fn) == "function"){
    return fn(arg1, arg2) || [] // May return undefined, null or falsy
  }
  return fn
}

export function match_traits({has, any, all}){
  has = has || []
  if (all){
    for (let a of all){
      if (has.indexOf(a)<0)
        return false
    }
  }
  if (any && any.length>0){
    for (let a of any){
      if (has.indexOf(a)>=0)
        return true
    }
    return false
  }
  else
    return true
}

/**
 * For each items uses the to_str_f function to extract a description text, and
 * all items at filters (a str list) must be in that description
 */
export function filter_items_str( items, filters, to_str_f = (s) => s){
  let ret = []
  let is_in = true
  for (let i of items){
    is_in = true
    let desc = to_str_f(i).toLocaleLowerCase()
    for (let f of filters){
      if (desc.indexOf(f)<0){
        is_in = false
        break;
      }
    }
    if (is_in)
      ret.push(i)
  }
  return ret
}

export default {
  to_map,
  to_list,
  dedup,
  flatmap,
  is_empty,
  map_drop,
  map_get,
  map_set,
  concat,
  sort_by_name,
  colorize,
  random_color,
  capitalize,
  merge,
  object_is_equal,
  pretty_ago,
  pretty_date,
  unwrap,
  match_traits,
  filter_items_str,

  days,
  months,
  templates
}

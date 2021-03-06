import store from './store'

export function perms(){
  const state=store.getState()
  if (state.auth.user)
    return store.getState().auth.user.perms
  return []
}

/**
 * Can be a perm expression, with AND and OR. And has higher priority.
 * It is very limited by design as there are no ()
 */
export function has_perm(perm){
  if (perm.indexOf(' AND ')>0)
    return perm.split(' AND ').every( (p) => has_perm(p) )
  if (perm.indexOf(' OR ')>0)
    return perm.split(' OR ').some( (p) => has_perm(p) )
  return perms().indexOf(perm)>=0
}

export default {perms, has_perm}

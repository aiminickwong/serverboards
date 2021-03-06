import { connect } from 'react-redux'
import View from 'app/components/service/actionmenu'
import { service_detach } from 'app/actions/service'
import { set_modal } from 'app/actions/modal'

var Container = connect(
  (state) => ({}),
  (dispatch) => ({
    setModal: (modal, data) => dispatch( set_modal(modal, data) )
  })
)(View)

export default Container

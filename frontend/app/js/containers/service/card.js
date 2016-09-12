import { connect } from 'react-redux'
import CardView from 'app/components/service/card'
import { service_detach } from 'app/actions/service'
import { set_modal } from 'app/actions/modal'

var Card = connect(
  (state) => {
    return {
      location: state.routing.locationBeforeTransitions
    }
  },
  (dispatch) => ({
    setModal: (modal, data) => dispatch( set_modal(modal, data) )
  })
)(CardView)

export default Card

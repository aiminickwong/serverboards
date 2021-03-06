const {React, cache} = Serverboards
import View from '../views/editaction'
const {Loading} = Serverboards.Components
const merge = Serverboards.utils.merge

class EditActionModel extends React.Component{
  constructor(props){
    super(props)

    console.log(this)
    const services = this.props.services
    const service_id = this.props.action.service
    const service = services.find( (s) => s.uuid == service_id )

    this.state = {
      actions: undefined,
      services,
      action: merge(this.props.action, {}),
      action_template: undefined,
      service,
      form_fields: [],
    }
  }
  componentDidMount(){
    const self = this
    cache.action_catalog().then( actions => {
      const action_id = self.props.action.action
      const action_template=actions.find( ac => ac.id == action_id )
      self.setState({ actions, action_template })
      return action_template
    }).then( (action_template) => {
      self.updateFormFields(action_template, this.state.service)
    })
  }
  handleActionChange(action_id){
    const action_template = this.findActionTemplate(action_id)
    this.setState({action_template, action: merge(this.state.action, {action: action_id})})
    this.updateFormFields(action_template, this.state.service)
  }
  updateFormFields(action_template, service){
    if (!action_template)
      this.setState({form_fields: []})
    else{
      let form_fields = action_template.extra.call.params

      if (service != undefined){
        const service_params = service.fields.map( (f) => f.name )
        form_fields = form_fields.filter( (p) => service_params.indexOf(p.name)<0 )
      }
      this.setState({form_fields})
    }
  }
  handleServiceChange(service_id){
    const service = this.findService(service_id)
    this.setState({service, action: merge(this.state.action, {service: service_id})})
    this.updateFormFields(this.state.action_template, service)
  }
  findActionTemplate(action_id){
    return this.state.actions.find( ac => ac.id == action_id )
  }
  findService(service_id){
    return this.state.services.find( (s) => s.uuid == service_id )
  }
  handleAcceptChanges(){
    console.log(this.state.action)
    this.props.onAccept(this.state.action)
  }
  updateAction(changes){
    console.log(changes)
    this.setState({action: merge(this.state.action, changes)})
  }
  render(){
    if (!this.state.actions || !this.state.services)
      return (
        <Loading>Actions and services</Loading>
      )
    return (
      <View {...this.props} {...this.state}
        onActionChange={this.handleActionChange.bind(this)}
        onServiceChange={this.handleServiceChange.bind(this)}
        onUpdateActionParams={(params) => this.updateAction({params})}
        onAccept={this.handleAcceptChanges.bind(this)}
        onUpdateDescription={(description) => this.updateAction({description})}
        onUpdateName={(name) => this.updateAction({name})}
        onUpdateConfirmation={(confirmation) => this.updateAction({confirmation})}
        onStar={(star) => this.updateAction({star})}
        onUpdateIcon={(icon) => this.updateAction({icon})}
        />
    )
  }
}

export default EditActionModel

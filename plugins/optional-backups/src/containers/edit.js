const {i18n, rpc, Flash, store, React} = Serverboards
const {Loading} = Serverboards.Components

import View from '../components/edit'
import {get_source_catalog, get_destination_catalog} from '../utils'

class EditBackup extends React.Component{
  constructor(props){
    super(props)

    this.state = {
      sources: undefined,
      destinations: undefined
    }
  }
  componentDidMount(){
    get_source_catalog()
      .then( sources => this.setState({sources}))
    get_destination_catalog()
      .then( destinations => this.setState({destinations}))
  }
  handleUpdateBackup(backup){
    const props = this.props
    rpc
      .call("plugin.data.update", ["serverboards.optional.backups", backup.id, backup])
      .then( () => {
        if (backup.schedule.days.length==0){
          Flash.warning(i18n("Update *{name}* backup, but as it has not any day enabled it is effectively disabled", {name: backup.name}))
        }
        else{
          Flash.success(i18n("Backup *{name}* updated.", {name: backup.name}))
        }
        props.gotoTab && props.gotoTab("details", backup)
      })
  }
  render(){
    if (!this.state.sources || !this.state.destinations)
      return(
        <Loading>{i18n("Available destinations and sources")}</Loading>
      )
    return (
      <View
        {...this.props}
        {...this.state}
        onUpdateBackup={!this.props.onAddBackup && ((b) => this.handleUpdateBackup(b)) }
        />
    )
  }
}

export default EditBackup

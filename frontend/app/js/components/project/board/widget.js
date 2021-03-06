import React from 'react'
import plugin from 'app/utils/plugin'
import {object_is_equal} from 'app/utils'
import {merge} from 'app/utils'
import Restricted from 'app/restricted'
import i18n from 'app/utils/i18n'

const Widget = React.createClass({
  umount: undefined,
  getInitialState(){
    return {
      title: undefined,
      error: false
    }
  },
  setTitle(title){
    this.setState({title})
  },
  find_service(uuid){
    //console.log("Find service %o in %o", uuid, this.props.services.map( (s) => s.uuid ))
    let service = this.props.services.find( (s) => s.uuid == uuid )
    //console.log("Got %o", service)
    if (!service)
      return {uuid: uuid, error: i18n("Not at current project, cant load full data.")}
    return service
  },
  decorate_config(config){
    config = merge(config, {project: this.props.project})
    const params = this.props.template.params || []
    for(let p of params){
      if (p.type=="service" && config[p.name]){
        const service = this.find_service(config[p.name])
        config[p.name]=service
      }
    }
    return config
  },
  do_widget(props){
    let self=this
    let plugin_component=props.template.id.split('/')
    const context={
      setTitle: self.setTitle,
      setError(err){ self.setState({error: err}) },
      plugin_id: plugin_component[0],
      component_id: plugin_component[1],
      widget_id: props.template.id,
      layout: props.layout
    }
    $(this.refs.el)
      .attr('data-pluginid', props.widget.split('/')[0])
      .attr('data-widgetid', props.widget)
      .attr('data-height', props.layout.height)
      .attr('data-width', props.layout.width)
    return plugin.do_widget(
      props.widget,
      this.refs.el,
      this.decorate_config(props.config),
      context
    ).then( (umount) => {
      this.umount=umount
    } )
  },
  componentDidMount(){
    Promise.all([plugin.load(`${this.props.widget}.js`),plugin.load(`${this.props.widget}.css`)]).then(
      () => this.do_widget(this.props)
    ).catch( (e) => {
      console.error(e)
      this.setState({error: String(e)})
      this.refs.el.html("")
    } )
  },
  componentWillUnmount(){
    this.umount && this.umount()
  },
  componentWillReceiveProps(nextprops){
    if (!object_is_equal(nextprops.config, this.props.config) ||
        (nextprops.layout && this.props.layout && !object_is_equal(nextprops.layout, this.props.layout))
      ){
        this.umount && this.umount()
        $(this.refs.el).html('')
        this.do_widget(nextprops)
    }
  },
  render(){
    const config = this.props.config || {}
    const widget = this.props.template || {}
    const state = this.state

    return (
      <div>
        <div className="ui top mini menu">
          <span className="ui header oneline">
            {state.title || config.name || widget.name}
          </span>
          <Restricted perm="dashboard.widget.update">
            <a className="item right" onClick={this.props.onEdit}>
              <i className="icon configure"/>
            </a>
          </Restricted>
        </div>
        {this.state.error ? (
          <section ref="error" className="plugin error">
            <div><i className="ui huge warning sign red icon"/></div>
            <div className="ui text red bold">{i18n("Error loading widget")}</div>
            <div className="ui meta">{widget.name}</div>
            <div className="ui meta">{this.props.widget}</div>
            <div style={{paddingTop:10}}>{this.state.error}</div>
          </section>
        ) : (
          <div ref="el"/>
        )}
      </div>
    )
  }
})


export default Widget

import React from 'react'

import GenericField from './genericfield'

const GenericForm=React.createClass({
  getInitialState(props){
    props = props || this.props
    let state={};
    (props.fields || []).map((f) => { if (f.name){ state[f.name]=(f.value || '') } } )
    if (props.data){
      Object.keys(props.data).map( (k) => { if (k){ state[k]=props.data[k] }})
    }
    return state
  },
  setValue : function(k, v){
    let update = {[k]: v }
    this.setState( update )
    let nstate=Object.assign({}, this.state, update ) // looks like react delays state change, I need it now
    //console.log(nstate, this.props)
    this.props.updateForm && this.props.updateForm(nstate)
  },
  componentWillReceiveProps(newprops){
    if (newprops.fields != this.props.fields || newprops.data != this.props.data){
      this.setState( this.getInitialState(newprops) )
    }
  },
  componentDidMount(){
    let fields = {};
    (this.props.fields || []).map((f) => {
      if (f.validation)
        fields[f.name]=f.validation
    })
    $(this.refs.form).form({ on: 'blur', fields }).on('submit', function(ev){
      ev.preventDefault()
    })
    this.props.updateForm && this.props.updateForm(this.state)
  },
  render(){
    const props=this.props
    return (
      <form
        ref="form"
        className={`ui form ${props.className || ""}`}
        onSubmit={(ev) => { ev.preventDefault(); props.onSubmit && props.onSubmit(ev) }}>
        {(props.fields || []).map((f) => (
            <GenericField key={f.name} setValue={this.setValue} value={this.state[f.name]} form_data={this.state} {...f}/>
        ))}
        {props.children}
      </form>
    )
  }
})

export default GenericForm

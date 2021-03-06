import React from 'react'
import { colorize } from 'app/utils'
import Icon from '../iconicon'
import cache from 'app/utils/cache'
import {MarkdownPreview} from 'react-marked-markdown'

class Card extends React.Component{
  constructor(props){
    super(props)
    this.state = {
      description: undefined
    }
  }
  componentDidMount(){
    if (!this.props.service.description){
      cache.service_type(this.props.service.type).then(st => this.setState({description: st.description}))
    }
  }
  render(){
    const props = this.props
    const {service, className} = props
    const description = service.description || this.state.description
    return (
      <div key={service.uuid} className={`ui narrow card ${className || ""}`} onClick={props.onClick}
           style={{cursor: props.onClick ? "pointer" : "cursor"}}>
        <div className="header">
          <Icon icon={service.icon} plugin={service.type.split('/')[0]} className="ui mini"/>
          <div className="right">
            {(service.tags || []).map( s => (
              <span key={s} className="ui text label">
                {s}&nbsp;
                <i className={`ui rectangular label ${ colorize( s ) }`}/>
              </span>
            ))}
          </div>
        </div>
        <div className="content">
          <h3 className="ui header">{service.name}</h3>
          <MarkdownPreview value={description}/>
        </div>
        <div className="extra content">
          {props.bottomElement && (
            <props.bottomElement service={service}/>
          )}
        </div>
      </div>
    )
  }
}

export default Card

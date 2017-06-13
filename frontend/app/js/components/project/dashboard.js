import React from 'react'
import {random_color} from 'app/utils'
import Board from 'app/containers/project/board'
import Loading from '../loading'
import HeaderMenu from 'app/containers/project/board/header'


const Overview = React.createClass({
  componentDidMount(){
    this.props.setSectionMenu(HeaderMenu)
  },
  render(){
    const props = this.props
    if (!props.project)
      return (
        <Loading>
          Serverboard data
        </Loading>
      )
    function tag(tagname){
      return (
        <span key={tagname} className={`ui label ${random_color(tagname)}`}>
          {tagname}
        </span>
      )
    }

    return (
      <div className="ui central board" id="dashboard">
        <Board location={props.location} project={props.project.shortname}/>
      </div>
    )
  }
})


export default Overview
